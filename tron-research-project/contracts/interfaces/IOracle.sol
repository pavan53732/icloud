// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IOracle
 * @dev Interface for price oracle integration
 * Supports multiple oracle types and chainlink compatibility
 */
interface IOracle {
    // Events for oracle updates
    event PriceUpdate(uint256 timestamp, uint256 price, address indexed updater);
    event OracleSwitch(address indexed oldOracle, address indexed newOracle);
    event FeedUpdate(string feedType, address feedAddress);

    // Core oracle functions
    function latestAnswer() external view returns (int256);
    function latestTimestamp() external view returns (uint256);
    function latestRound() external view returns (uint256);
    function getAnswer(uint256 roundId) external view returns (int256);
    function getTimestamp(uint256 roundId) external view returns (uint256);

    // Extended oracle functions
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    // Custom oracle functions for advanced spoofing
    function setCustomPrice(uint256 price) external;
    function enableDynamicPricing(bool enable) external;
    function setPriceDeviation(uint256 deviationBps) external;
    function setUpdateFrequency(uint256 seconds) external;
}