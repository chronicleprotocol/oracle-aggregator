// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {NumericArrayLib} from "./libs/NumericArrayLib.sol";
import {IChronicle} from "./IChronicle.sol";
import {IOracleAggregator} from "./IOracleAggregator.sol";

/**
 * @title OracleAggregator
 * @author The Redstone Oracles team
 * @notice This contract aggregates price data from multiple blockchain oracles: Chainlink, Chronicle, and RedStone.
 *
 * Important note: This aggregator does not check the decimals of the configured feeds. 
 * Ensure `redstone()` and `chainlink()` return values with 8 decimals, and `chronicle()` returns 18 decimals internally.
 * 
 * ## Key Principles:
 * - **Simplicity:** The contract is designed to be as simple as possible to minimize the risk of bugs.
 * - **Immutable Configuration:** There are no in-contract authorization mechanisms for admin wallets. Any changes require deploying a new version of the contract.
 * - **Partial AggregatorV3Interface Implementation:** The contract implements only `latestRoundData` and `latestAnswer` functions to reduce complexity.
 * - **Whitelisted Reads:** Only authorized addresses can call `latestRoundData` and `latestAnswer`. Access is configured in the `checkAuthorisedDataConsumer` method.
 * - **Gas Optimization:** Uses low-level calls and avoids unnecessary storage reads to reduce gas consumption.
 * - **Oracle Isolation:** Each oracle call has a gas limit and low-level error handling to isolate failures. This ensures that a malfunction or compromise of one oracle won't impact the aggregator's reliability.
 * - **Separation of Concerns:** The core logic resides in this contract (`OracleAggregator.sol`), while the configuration is handled in separate contracts (e.g. `ETH_Oracle_Aggregated_Redstone_Chainlink_Chronicle.sol`).
 */
abstract contract OracleAggregator is AggregatorV3Interface, IOracleAggregator {
    /// @notice Thrown when a function is called that is not supported by this aggregator.
    error UnsupportedFunction();

    /// @notice The number of decimals for the final aggregated price.
    uint8 public constant decimals = 8;

    // Internal constants
    uint256 internal constant _CHRONICLE_DECIMALS = 18;
    uint256 internal constant _CHRONICLE_SCALE_FAKTOR = 10 ** (_CHRONICLE_DECIMALS - decimals);
    uint256 internal constant _GAS_LIMIT_PER_ORACLE_READ = 500_000; // Average gas cost for oracle calls is ~20K. It's quite safe, but in case of ethereum hardforks (with signifncant changes in gas calculation) we would need to deploy a new version of this contract
    uint256 internal constant _LATEST_ROUND_DATA_RETURN_SIZE = 160;
    uint256 internal constant _TRY_READ_WITH_AGE_RETURN_SIZE = 96;

    /// @inheritdoc IOracleAggregator
    function chainlink() public view virtual returns(AggregatorV3Interface);

    /// @inheritdoc IOracleAggregator
    function redstone() public view virtual returns(AggregatorV3Interface);

    /// @inheritdoc IOracleAggregator
    function chronicle() public view virtual returns(IChronicle);

    /// @inheritdoc IOracleAggregator
    function checkAuthorisedDataConsumer(address consumer) public view virtual;

    /// @inheritdoc IOracleAggregator
    function getAgeThreshold() public view virtual returns(uint32);

    /// @inheritdoc IOracleAggregator
    function getAggregatedOracleValue() public view returns (uint256 value, uint8 goodOraclesCount) {
        (bool okChronicle, uint256 valChronicle) = _safeReadFromChronicle();
        (bool okChainlink, uint256 valChainlink) = _safeLatestRoundData(chainlink());
        (bool okRedstone, uint256 valRedstone) = _safeLatestRoundData(redstone());

        assembly {
            goodOraclesCount := add(add(okChronicle, okChainlink), okRedstone) // ((okChronicle ? 1 : 0) + (okChainlink ? 1 : 0)) + (okRedstone ? 1 : 0)
        }
        uint256 insertIndex = 0;
        uint256[] memory values = new uint256[](goodOraclesCount);

        if (okChronicle) values[insertIndex++] = valChronicle;
        if (okChainlink) values[insertIndex++] = valChainlink;
        if (okRedstone) values[insertIndex++] = valRedstone;

        value = NumericArrayLib.pickMedian(values);
    }

    /**
     * @notice Safely calls `latestRoundData` on a Chainlink-compatible Price Feed contract
     * @dev The priceFeed must have use 8 decimals
     * @param priceFeed The address of the Chainlink Price Feed contract
     * @return success If the call succeeded and is not stale
     * @return value The oracle value (with 8 decimals)
     */
    function _safeLatestRoundData(AggregatorV3Interface priceFeed) internal view returns (bool success, uint256 value) {
        bytes memory data = abi.encodeWithSelector(
            AggregatorV3Interface.latestRoundData.selector
        );

        bytes memory returnData;

        (success, returnData) = address(priceFeed).staticcall{gas: _GAS_LIMIT_PER_ORACLE_READ}(data);

        if (success && returnData.length == _LATEST_ROUND_DATA_RETURN_SIZE) { // Checking returnData.length to avoid failures in abi.decode
            (/* roundId */, int256 answer, /* startedAt */, uint256 updatedAt, /* answeredInRound */) =
                abi.decode(returnData, (uint80, int256, uint256, uint256, uint80));

            bool isStale;
            unchecked {
                isStale = updatedAt < block.timestamp - getAgeThreshold();
            }

            if (isStale || answer <= 0 || uint256(answer) > uint256(type(uint128).max)) {
                return (false, 0);
            }

            return (true, uint256(answer));
        }
        
        return (false, 0);
    }

    /**
     * @notice Safely calls `tryReadWithAge` on the Chronicle Oracle contract.
     * @return success True if the call was successful and the data is valid and not stale.
     * @return value The oracle's returned price value, scaled to 8 decimals.
     */
    function _safeReadFromChronicle() internal view returns (bool success, uint256 value) {
        bytes memory data = abi.encodeWithSelector(IChronicle.tryReadWithAge.selector);
        (bool callSuccess, bytes memory returnData) = address(chronicle()).staticcall{gas: _GAS_LIMIT_PER_ORACLE_READ}(data);

        if (callSuccess && returnData.length == _TRY_READ_WITH_AGE_RETURN_SIZE) { // Checking returnData.length to avoid failures in abi.decode
            (bool isValid, uint256 chronicleValue, uint256 age) = abi.decode(returnData, (bool, uint256, uint256));

            if (!isValid) {
                return (false, 0);
            }

            bool isStale;
            unchecked {
                isStale = age < block.timestamp - getAgeThreshold();
            }

            if (isStale) { // We don't do assertions for the size of the number here, because we will divide the value by 10**10 below
                return (false, 0);
            }

            chronicleValue /= _CHRONICLE_SCALE_FAKTOR;

            return (true, chronicleValue);
        }

        return (false, 0);
    }

    /**
     * @notice Returns the latest round data as defined by `AggregatorV3Interface`.
     * @dev Only authorized data consumers can read the data.
     * @return roundId A fixed round ID (always 1 in this implementation).
     * @return answer The aggregated price as an `int256`.
     * @return startedAt The current block timestamp (we don't aggregate timestamps from different oracles).
     * @return updatedAt The current block timestamp (we don't aggregate timestamps from different oracles).
     * @return answeredInRound Equal to `roundId`.
     */
    function latestRoundData()
        external
        view
        virtual
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        checkAuthorisedDataConsumer(msg.sender);
        (uint256 value, /* goodOraclesCount */) = getAggregatedOracleValue();

        roundId = 1;
        answer = int256(value);
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }

    /**
     * @notice Returns the latest aggregated answer as defined by `AggregatorV3Interface`.
     * @dev Only authorized data consumers can read the data.
     * @return The aggregated price as an `int256`.
     */
    function latestAnswer() external view returns (int256) {
        checkAuthorisedDataConsumer(msg.sender);
        (uint256 value, /* goodOraclesCount */) = getAggregatedOracleValue();

        return int(value);
    }

    /// @notice This function is not supported.
    function latestRound() external pure virtual returns (uint80) {
        revert UnsupportedFunction();
    }

    /// @notice This function is not supported.
    function getRoundData(uint80 /* requestedRoundId */) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert UnsupportedFunction();
    }

    /**
     * @notice Returns the version of this aggregator
     * @return version
     */
    function version() external virtual pure override returns (uint256) {
        return 1;
    }
}
