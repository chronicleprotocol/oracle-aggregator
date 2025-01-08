// SPDX-License-Identifier: BUSL-1.1

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
 * ## Key Principles:
 * - **Simplicity:** The contract is designed to be as simple as possible to minimize the risk of bugs.
 * - **Immutable Configuration:** There are no in-contract authorization mechanisms for admin wallets. Any changes require deploying a new version of the contract.
 * - **Partial AggregatorV3Interface Implementation:** The contract implements only `latestRoundData` and `latestAnswer` functions to reduce complexity.
 * - **Whitelisted Reads:** Only authorized addresses can call Chainlink functions. It can be configured in the `checkAuthorisedDataConsumer` method.
 * - **Gas Optimization:** Uses low-level calls and avoids unnecessary storage reads to reduce gas consumption.
 * - **Oracle Isolation:** Each oracle call has a gas limit and low-level error handling to isolate failures. This ensures that a malfunction or compromise of one oracle won't impact the aggregator's reliability.
 * - **Separation of Concerns:** The core logic resides in this contract (`OracleAggregator.sol`), while the configuration is handled in separate contracts (e.g. `ETH_Oracle_Aggregated_Redstone_Chainlink_Chronicle.sol`).
 */
abstract contract OracleAggregator is AggregatorV3Interface, IOracleAggregator {
    error UnsupportedFunction();

    // Decimals used by Chronicle
    uint8 internal constant _DECIMALS_CHRONICLE = 18;
    uint256 internal constant _GAS_LIMIT_PER_ORACLE_READ = 300_000; // Average gas cost for oracle calls is ~20K
    uint256 internal constant _LATEST_ROUND_DATA_RETURN_SIZE = 160;
    uint256 internal constant _TRY_READ_WITH_AGE_RETURN_SIZE = 96;

    uint8 public constant decimals = 8;

    function chronicle() public view virtual returns(address);
    function chainlink() public view virtual returns(address);
    function redstone() public view virtual returns(address);
    function checkAuthorisedDataConsumer(address consumer) public view virtual;
    function getAgeThreshold() public view virtual returns(uint32);

    // Diagnostic function, everyone can call it (it's not protected by the `checkAuthorisedDataConsumer`)
    function getAggregatedOracleValue() public view returns (uint256 value, uint8 goodOraclesCount) {
        (bool okChronicle, uint256 valChronicle) = _safeReadFromChronicle();
        (bool okChainlink, uint256 valChainlink) = _safeLatestRoundData(chainlink());
        (bool okRedstone, uint256 valRedstone) = _safeLatestRoundData(redstone());

        uint256 index = 0;
        goodOraclesCount = (okChronicle ? 1 : 0) + (okChainlink ? 1 : 0) + (okRedstone ? 1 : 0);
        uint256[] memory values = new uint256[](goodOraclesCount);

        if (okChronicle) values[index++] = valChronicle;
        if (okChainlink) values[index++] = valChainlink;
        if (okRedstone) values[index++] = valRedstone;

        value = NumericArrayLib.pickMedian(values);
    }

    /**
     * @notice Safely calls `latestRoundData` on a Chainlink-compatible Price Feed contract
     * @param priceFeed The address of the Chainlink Price Feed contract
     * @return success If the call succeeded and is not stale
     * @return val The oracle value
     */
    function _safeLatestRoundData(address priceFeed) internal view returns (bool success, uint256 val) {
        bytes memory data = abi.encodeWithSelector(
            AggregatorV3Interface.latestRoundData.selector
        );

        bytes memory returnData;

        (success, returnData) = priceFeed.staticcall{gas: _GAS_LIMIT_PER_ORACLE_READ}(data);

        if (success && returnData.length == _LATEST_ROUND_DATA_RETURN_SIZE) { // Checking returnData.length to avoid failures in abi.decode
            (/* roundId */, int256 answer, /* startedAt */, uint256 updatedAt, /* answeredInRound */) =
                abi.decode(returnData, (uint80, int256, uint256, uint256, uint80));

            bool isStale;
            unchecked {
                isStale = updatedAt + getAgeThreshold() < block.timestamp;
            }

            if (isStale || answer <= 0 || uint256(answer) > uint256(type(uint128).max)) {
                return (false, 0);
            }

            return (true, uint256(answer));
        }
        
        return (false, 0);
    }

    /**
     * @notice Safely calls `tryReadWithAge` on the Chronnicle Oracle contract
     * @return success If the call succeeded and is not stale
     * @return val The oracle value
     */
    function _safeReadFromChronicle() internal view returns (bool, uint256) {
        bytes memory data = abi.encodeWithSelector(IChronicle.tryReadWithAge.selector);
        (bool callSuccess, bytes memory returnData) = chronicle().staticcall{gas: _GAS_LIMIT_PER_ORACLE_READ}(data);

        if (callSuccess && returnData.length == _TRY_READ_WITH_AGE_RETURN_SIZE) { // Checking returnData.length to avoid failures in abi.decode
            (bool isValid, uint256 value, uint256 age) = abi.decode(returnData, (bool, uint256, uint256));

            if (!isValid) {
                return (false, 0);
            }

            bool isStale;
            unchecked {
                isStale = age + getAgeThreshold() < block.timestamp;
            }

            if (isStale) { // We don't do assert(value <= type(uint128).max), because we will divide the value by 10**10 below
                return (false, 0);
            }

            value /= 10 ** (_DECIMALS_CHRONICLE - decimals);

            return (true, value);
        }

        return (false, 0);
    }

    function latestRoundData()
        external
        view
        virtual
        returns (
            uint80 roundId,
            int answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        checkAuthorisedDataConsumer(msg.sender);
        (uint256 val, /* goodOraclesCount */) = getAggregatedOracleValue();

        roundId = 1;
        answer = int(val);
        startedAt = 0;
        updatedAt = block.timestamp;
        answeredInRound = 1; // = roundId
    }

    function latestAnswer() external view returns (int256) {
        checkAuthorisedDataConsumer(msg.sender);
        (uint256 val, /* goodOraclesCount */) = getAggregatedOracleValue();

        return int(val);
    }

    function latestRound() external pure virtual returns (uint80) {
        revert UnsupportedFunction();
    }

    function getRoundData(uint80 /* requestedRoundId */) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert UnsupportedFunction();
    }

    function version() external virtual pure override returns (uint256) {
        return 1;
    }
}
