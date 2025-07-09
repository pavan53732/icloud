// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFlashLoanSimpleReceiver, IPoolAddressesProvider, IPool} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract FlashAaveArbBot is IFlashLoanSimpleReceiver, ReentrancyGuard {
    address public owner;
    address public profitReceiver;
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;

    event SwapExecuted(address indexed from, address indexed to, uint256 amountIn, uint256 amountOut, address dex);
    event ProfitSent(address indexed recipient, uint256 amount);
    event LoanFailed(string reason, address[] route, address[] dexes, uint256 minAmountOut);
    event TradeOnChainLog(
        address initiator,
        address[] route,
        address[] dexes,
        uint256 amountIn,
        uint256 amountOut,
        uint256 profit,
        uint256 gasUsed,
        uint256 timestamp,
        bool success
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _profitReceiver, address provider) {
        owner = msg.sender;
        profitReceiver = _profitReceiver;
        ADDRESSES_PROVIDER = IPoolAddressesProvider(provider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
    }

    function startFlashArb(
        address asset,
        uint256 amount,
        address[] calldata route,
        address[] calldata dexes,
        uint256 minAmountOut,
        bool autoToStable,
        address stableRouter,
        address stableToken
    ) external onlyOwner nonReentrant {
        require(route.length >= 3, "route too short");
        require(dexes.length == route.length - 1, "dexes mismatch route");
        POOL.flashLoanSimple(address(this), asset, amount, abi.encode(route, dexes, minAmountOut, autoToStable, stableRouter, stableToken), 0);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override nonReentrant returns (bool) {
        require(msg.sender == address(POOL), "Not pool");
        require(initiator == address(this), "Not initiated");

        (address[] memory route, address[] memory dexes, uint256 minAmountOut, bool autoToStable, address stableRouter, address stableToken) =
            abi.decode(params, (address[], address[], uint256, bool, address, address));
        uint deadline = block.timestamp + 300;
        uint currentAmount = amount;
        uint gasStart = gasleft();
        bool success = true;

        for (uint i = 0; i < dexes.length; i++) {
            IERC20(route[i]).approve(dexes[i], currentAmount);
            uint amountOutMin = (i == dexes.length - 1) ? minAmountOut : 0;
            uint[] memory amounts = IUniswapV2Router(dexes[i]).swapExactTokensForTokens(
                currentAmount,
                amountOutMin,
                getPath(route[i], route[i+1]),
                address(this),
                deadline
            );
            emit SwapExecuted(route[i], route[i+1], currentAmount, amounts[1], dexes[i]);
            currentAmount = amounts[1];
        }

        uint totalOwed = amount + premium;
        if (currentAmount < totalOwed) {
            emit LoanFailed("Not enough to repay loan", route, dexes, minAmountOut);
            success = false;
        } else {
            IERC20(asset).approve(address(POOL), totalOwed);
            uint profit = currentAmount - totalOwed;
            if (profit > 0) {
                if (autoToStable && stableToken != address(0) && stableRouter != address(0)) {
                    IERC20(asset).approve(stableRouter, profit);
                    uint[] memory amounts = IUniswapV2Router(stableRouter).swapExactTokensForTokens(
                        profit,
                        1,
                        getPath(asset, stableToken),
                        profitReceiver,
                        deadline
                    );
                    emit ProfitSent(profitReceiver, amounts[1]);
                } else {
                    IERC20(asset).transfer(profitReceiver, profit);
                    emit ProfitSent(profitReceiver, profit);
                }
            }
        }

        emit TradeOnChainLog(
            tx.origin,
            route,
            dexes,
            amount,
            currentAmount,
            (currentAmount > totalOwed ? currentAmount - totalOwed : 0),
            gasStart - gasleft(),
            block.timestamp,
            success
        );

        return success;
    }

    function setProfitReceiver(address _profitReceiver) external onlyOwner {
        profitReceiver = _profitReceiver;
    }

    function rescueTokens(address token) external onlyOwner {
        uint bal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, bal);
    }

    function getPath(address a, address b) internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = a;
        path[1] = b;
    }
}