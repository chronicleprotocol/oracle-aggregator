// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IChronicle} from "./IChronicle.sol";
import {OracleAggregator, IOracleAggregator} from "./OracleAggregator.sol";

/**
 * @title ETH_Oracle_Aggregated_Chronicle_Chainlink_Redstone
 * @notice A concrete implementation of the OracleAggregator designed specifically for ETH/USD.
 */
contract ETH_Oracle_Aggregated_Chronicle_Chainlink_Redstone is OracleAggregator {
    /// @notice Thrown when a caller is not an authorized data consumer.
    error UnathorisedDataConsumer(address consumer);

    /**
     * @notice Returns a brief description of this price feed.
     * @dev For compatibility with Chainlink’s AggregatorV3Interface.
     * @return description A human-readable description of the aggregator.
     */
    function description() public view virtual override returns (string memory) {
        return "Aggregated price feed ETH/USD from Chronicle, Chainlink, and RedStone oracles";
    }
    
    /// @inheritdoc IOracleAggregator
    function chronicle() public pure virtual override returns(IChronicle) {
        return IChronicle(0x46ef0071b1E2fF6B42d36e5A177EA43Ae5917f4E);
    }

    /// @inheritdoc IOracleAggregator
    function chainlink() public pure virtual override returns(AggregatorV3Interface) {
        return AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

    /// @inheritdoc IOracleAggregator
    function redstone() public pure virtual override returns(AggregatorV3Interface) {
        return AggregatorV3Interface(0x67F6838e58859d612E4ddF04dA396d6DABB66Dc4);
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
