// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IChronicle} from "./IChronicle.sol";

interface IOracleAggregator {

    function getAggregatedOracleValue() external view returns (uint256 value, uint8 goodOraclesCount);

    // Immutable Configurations

    function chronicle() external view returns (IChronicle chronicle);
    function chainlink() external view returns (AggregatorV3Interface chainlink); // Must be a price feed with decimals == 8
    function redstone() external view returns (AggregatorV3Interface redstone); // Must be a price feed with decimals == 8
    function getAgeThreshold() external view returns(uint32);
    function checkAuthorisedDataConsumer(address consumer) external view;
}
