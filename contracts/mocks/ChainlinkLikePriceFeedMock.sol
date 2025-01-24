// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkLikePriceFeedMock is AggregatorV3Interface {
    error ZeroValueIsInvalid();

    int256 private _price;
    uint256 private _timestamp;
    uint80 private _roundId;
    bool private _gasConsumingModeEnabled;

    // Function to set mock price, round ID, and timestamp
    function setValue(int256 price, uint80 roundId, uint256 timestamp) external {
        _price = price;
        _roundId = roundId;
        _timestamp = timestamp;
    }

    function enableGasConsumingMode() external {
        _gasConsumingModeEnabled = true;
    }

    // Mock implementation of latestRoundData
    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        if (_gasConsumingModeEnabled) {
            bytes32[] memory arr = new bytes32[](1000000);
        }

        if (_price == 0) {
            revert ZeroValueIsInvalid();
        }

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
