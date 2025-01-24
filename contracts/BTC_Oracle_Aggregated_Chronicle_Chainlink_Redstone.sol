// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IChronicle} from "./IChronicle.sol";
import {OracleAggregator, IOracleAggregator} from "./OracleAggregator.sol";

/**
 * @title BTC_Oracle_Aggregated_Chronicle_Chainlink_Redstone
 * @notice A concrete implementation of the OracleAggregator designed specifically for BTC/USD.
 */
contract BTC_Oracle_Aggregated_Chronicle_Chainlink_Redstone is OracleAggregator {
    /// @notice Thrown when a caller is not an authorized data consumer.
    error UnathorisedDataConsumer(address consumer);

    /**
     * @notice Returns a brief description of this price feed.
     * @dev For compatibility with Chainlink’s AggregatorV3Interface.
     * @return description A human-readable description of the aggregator.
     */
    function description() public view virtual override returns (string memory) {
        return "Aggregated price feed BTC/USD from Chronicle, Chainlink, and RedStone oracles";
    }
    
    /// @inheritdoc IOracleAggregator
    function chronicle() public pure virtual override returns(IChronicle) {
        return IChronicle(0x24C392CDbF32Cf911B258981a66d5541d85269ce);
    }

    /// @inheritdoc IOracleAggregator
    function chainlink() public pure virtual override returns(AggregatorV3Interface) {
        return AggregatorV3Interface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
    }

    /// @inheritdoc IOracleAggregator
    function redstone() public pure virtual override returns(AggregatorV3Interface) {
        return AggregatorV3Interface(0xAB7f623fb2F6fea6601D4350FA0E2290663C28Fc);
    }

    /// @inheritdoc IOracleAggregator
    function checkAuthorisedDataConsumer(address consumer) public pure virtual override {
        // Open for everyone
    }

    /// @inheritdoc IOracleAggregator
    function getAgeThreshold() public pure virtual override returns(uint32) {
        return 25 hours; // in seconds
    }

}
