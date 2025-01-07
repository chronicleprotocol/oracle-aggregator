// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// TODO: add features for OOG tests

contract ChainlinkLikePriceFeedMock is AggregatorV3Interface {
    int256 private _price;
    uint256 private _timestamp;
    uint80 private _roundId;

    // Function to set mock price, round ID, and timestamp
    function setValue(int256 price, uint80 roundId, uint256 timestamp) external {
        _price = price;
        _roundId = roundId;
        _timestamp = timestamp;
    }

    // Mock implementation of latestRoundData
    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (_roundId, _price, 0, _timestamp, _roundId);
    }

    // Other functions revert as they are not implemented
    function decimals() external pure override returns (uint8) {
        revert();
    }

    function description() external pure override returns (string memory) {
        revert();
    }

    function version() external pure override returns (uint256) {
        revert();
    }

    function getRoundData(uint80) external pure override returns (
        uint80,
        int256,
        uint256,
        uint256,
        uint80
    ) {
        revert();
    }
}
