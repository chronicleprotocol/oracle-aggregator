// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IChronicle} from "./IChronicle.sol";

/**
 * @title IOracleAggregator
 * @notice Interface for a contract that aggregates data from multiple oracle sources.
 */
interface IOracleAggregator {

    /**
     * @notice Fetches the aggregated oracle value from multiple sources.
     * @return value The median price from all valid oracles.
     * @return goodOraclesCount The number of oracles that returned a valid, non-stale value.
     */
    function getAggregatedOracleValue() external view returns (uint256 value, uint8 goodOraclesCount);


    // Immutable Configurations

    /**
     * @notice Returns the Chronicle oracle contract.
     * @dev Must be configured to return 18-decimals price data.
     * @return chronicle The chronicle oracle contract address.
     */
    function chronicle() external view returns (IChronicle chronicle);

    /**
     * @notice Returns the Chainlink oracle contract.
     * @dev Must be a price feed with 8 decimals.
     * @return chainlink The Chainlink PriceFeed address.
     */
    function chainlink() external view returns (AggregatorV3Interface chainlink);

    /**
     * @notice Returns the RedStone oracle contract.
     * @dev Must be a price feed with 8 decimals.
     * @return redstone The RedStone PriceFeed address.
     */
    function redstone() external view returns (AggregatorV3Interface redstone);

    /**
     * @notice Returns the maximum allowed age of price data (in seconds) for it to be considered valid.
     * @dev The age threshold is used to prevent stale prices from being counted.
     * @return ageThreshold The age threshold, in seconds.
     */
    function getAgeThreshold() external view returns(uint32);

    /**
     * @notice Checks whether a given address is authorized to consume price data.
     * @dev Reverts if the consumer is not authorized. This check is used only in
     *      the `latestAnswer` and the `latestRoundData` functions. The `getAggregatedOracleValue`
     *      function is open for everyone
     * @param consumer The address for which to check authorization.
     */
    function checkAuthorisedDataConsumer(address consumer) external view;
}
