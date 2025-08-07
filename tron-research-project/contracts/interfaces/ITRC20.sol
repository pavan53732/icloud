// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ITRC20
 * @dev Interface matching exact USDT TRC20 standard on Tron
 * All function signatures, events, and selectors match mainnet USDT
 */
interface ITRC20 {
    // Events matching real USDT exactly
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Issue(uint256 amount);
    event Redeem(uint256 amount);
    event Deprecate(address newAddress);
    event Params(uint256 feeBasisPoints, uint256 maxFee);
    event DestroyedBlackFunds(address indexed blackListedUser, uint256 balance);
    event AddedBlackList(address indexed user);
    event RemovedBlackList(address indexed user);
    event Pause();
    event Unpause();

    // Standard TRC20 functions
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    // USDT-specific functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function getOwner() external view returns (address);
    function issue(uint256 amount) external;
    function redeem(uint256 amount) external;
    function setParams(uint256 newBasisPoints, uint256 newMaxFee) external;
    function deprecate(address _upgradedAddress) external;
    function addBlackList(address _evilUser) external;
    function removeBlackList(address _clearedUser) external;
    function destroyBlackFunds(address _blackListedUser) external;
    function isBlackListed(address) external view returns (bool);
    function getBlackListStatus(address _maker) external view returns (bool);
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
    function upgradedAddress() external view returns (address);
    function deprecated() external view returns (bool);
    function basisPointsRate() external view returns (uint256);
    function maximumFee() external view returns (uint256);

    // Additional metadata functions
    function website() external view returns (string memory);
    function audit() external view returns (string memory);
    function reserves() external view returns (uint256);
    function insurance() external view returns (string memory);
    function compliance() external view returns (string memory);
}