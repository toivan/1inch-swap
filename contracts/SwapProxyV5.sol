// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "hardhat/console.sol";

contract SwapProxyV5 is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    struct OneInchSwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    address public oneInchAggregationRouterV5;

    event OneInchSwap(IERC20 sellToken, IERC20 buyToken, uint256 boughtAmount);
    /// 1inch exchange router contract change
    event SetExchangeProxy(address oneInchAggregationRouter);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address router) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        oneInchAggregationRouterV5 = router;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Performs a swap, delegating all calls encoded in `_data`.
    /// @param minOut The minimum amount of tokens received
    /// @param _data Encoded calls that `caller` should execute
    function oneInchSwap(uint minOut, bytes calldata _data) external {
        (address swapTarget, OneInchSwapDescription memory desc, bytes memory permit, bytes memory data) = abi.decode(_data[4:], (address, OneInchSwapDescription, bytes, bytes));
        console.log("swapTarget", swapTarget);
        // Checks that the swapTarget is actually the address of AggregationRouterV5
        // require(swapTarget == oneInchAggregationRouterV5, "(swapOneInch) Target not 1inch Router");

        IERC20 sellToken = desc.srcToken;
        IERC20 buyToken = desc.dstToken;

        address srcTokenAddress = address(sellToken);
        address dstTokenAddress = address(buyToken);
/*         console.log("oneInchAggregationRouterV5", oneInchAggregationRouterV5);
        console.log("Transferring from %s to %s tokens", srcTokenAddress, dstTokenAddress);
        console.log("data", string(abi.encodePacked(data))); */

        IERC20(desc.srcToken).transferFrom(msg.sender, address(this), desc.amount);
        IERC20(desc.srcToken).approve(oneInchAggregationRouterV5, desc.amount);

        (bool success, bytes memory __data) = address(oneInchAggregationRouterV5).call(_data);
        uint256 boughtAmount;
        if (success) {
            (uint returnAmount, uint spentAmount) = abi.decode(__data, (uint, uint));
            require(returnAmount >= minOut);
            boughtAmount = returnAmount;
            console.log("returnAmount", returnAmount);
            console.log("spentAmount", spentAmount);
        } else {
            revert();
        }
        emit OneInchSwap(sellToken, buyToken, boughtAmount); // sellTokenLeftover
    }

    /// Set new 1inch Router address
    /// @param _oneInchRouter New exchange contract of 1inch
    function setExchangeProxy(address _oneInchRouter) external onlyOwner {
        oneInchAggregationRouterV5 = _oneInchRouter;
        emit SetExchangeProxy(oneInchAggregationRouterV5);
    }
}
