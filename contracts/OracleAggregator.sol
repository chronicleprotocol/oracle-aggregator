// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {NumericArrayLib} from "@redstone-finance/evm-connector/contracts/libs/NumericArrayLib.sol";
import {IChronicle} from "./IChronicle.sol";
import {IOracleAggregator} from "./IOracleAggregator.sol";

// - We need to implement many gas-related tests to check different cases, e.g. when gas finished on one of the calls
// I think it still should be ok. But we should also try to manipulate and cause failres by too-gas-consuming PriceFeeds

abstract contract OracleAggregator is AggregatorV3Interface, IOracleAggregator {
    /// @dev The decimals value used by Chronicle Protocol oracles.
    uint8 internal constant _DECIMALS_CHRONICLE = 18;
    uint256 internal constant _GAS_LIMIT_PER_ORACLE_READ = 100_000;

    uint32 public constant ageThreshold = 2 days;
    uint8 public constant decimals = 8;


    constructor() {}

    function chronicle() public pure virtual returns(address);
    function chainlink() public pure virtual returns(address);
    function redstone() public pure virtual returns(address);
    function checkAuthorisedDataConsumer(address sender) public pure virtual;

    function _read() internal view returns (uint256 value, uint8 goodOraclesCount) {
        checkAuthorisedDataConsumer(msg.sender);
        (bool okChr, uint256 valChr) = _readChronicle();
        (bool okChl, uint256 valChl) = _safeLatestRoundData(chainlink());
        (bool okRed, uint256 valRed) = _safeLatestRoundData(redstone());

        uint256 index = 0;
        goodOraclesCount = (okChr ? 1 : 0) + (okChl ? 1 : 0) + (okRed ? 1 : 0);
        uint256[] memory values = new uint256[](goodOraclesCount);

        if (okChr) values[index++] = valChr;
        if (okChl) values[index++] = valChl;
        if (okRed) values[index++] = valRed;

        value = NumericArrayLib.pickMedian(values);
    }

    /**
     * @notice Safely calls `latestRoundData` on a Chainlink Price Feed.
     * @param priceFeed The address of the Chainlink Price Feed.
     * @return success Whether the call succeeded.
     * @return val The oracle value
     */
    function _safeLatestRoundData(address priceFeed) internal view returns (bool success, uint256 val) {
        bytes memory data = abi.encodeWithSelector(
            AggregatorV3Interface.latestRoundData.selector
        );

        bytes memory returnData;

        (success, returnData) = priceFeed.staticcall{gas: _GAS_LIMIT_PER_ORACLE_READ}(data);

        if (success && returnData.length == 160) {
            // TODO: replace with abi.decode
            uint80 roundId;
            int256 answer;
            uint256 startedAt;
            uint256 updatedAt;
            uint80 answeredInRound;

            assembly {
                roundId := mload(add(returnData, 0x20))
                answer := mload(add(returnData, 0x40))
                startedAt := mload(add(returnData, 0x60))
                updatedAt := mload(add(returnData, 0x80))
                answeredInRound := mload(add(returnData, 0xa0))
            }

            bool isStale;
            unchecked {
                isStale = updatedAt + ageThreshold < block.timestamp;
            }

            // Fail if answer stale or not in [1, type(uint128).max].
            if (
                isStale || answer <= 0 || uint(answer) > uint(type(uint128).max)
            ) {
                return (false, 0);
            }

            // Otherwise return the value
            return (true, uint256(answer));
        } else {
            return (false, 0);
        }
    }

    // TODO: modify this function to avoid issues with code rights
    function _readChronicle() internal view returns (bool, uint256) {
        bytes memory data = abi.encodeWithSelector(IChronicle.tryReadWithAge.selector);
        (bool callSuccess, bytes memory returnData) = chronicle().staticcall(data);

        // TODO: add staleness checking

        if (callSuccess && returnData.length == 64) {
            (bool validOracleResponse, uint256 value, uint256 age) = abi.decode(returnData, (bool, uint256, uint256));

            if (!validOracleResponse || age + ageThreshold < block.timestamp) {
                return (false, 0);
            }

            value /= 10 ** (_DECIMALS_CHRONICLE - decimals);

            return (true, value);
        } else {
            return (false, 0);
        }

        // TODO: complete the safe implementation of chronicle

        // // Note that Chronicle's `try...` functions revert iff the caller is not
        // // toll'ed.
        // try IChronicle(chronicle).tryReadWithAge() returns (
        //     bool ok, uint val, uint age
        // ) {
        //     // assert(val <= type(uint128).max);
        //     // assert(!ok || val != 0); // ok -> val != 0
        //     // assert(age <= block.timestamp);

        //     // Fail if not ok or value stale.
        //     if (!ok || age + ageThreshold < block.timestamp) {
        //         return (false, 0);
        //     }

        //     // Scale value down from Chronicle decimals to Aggor decimals.
        //     // assert(_DECIMALS_CHRONICLES >= decimals).
        //     val /= 10 ** (_DECIMALS_CHRONICLE - decimals);

        //     return (true, val);
        // } catch {
        //     // assert(!IToll(chronicle).tolled(address(this)));
        //     return (false, 0);
        // }
    }

    function latestRoundData()
        external
        view
        virtual
        returns (
            uint80 roundId,
            int answer,
            uint startedAt,
            uint updatedAt,
            uint80 answeredInRound
        )
    {
        (uint256 val, /* goodOraclesCount */) = _read();

        roundId = 1;
        answer = int(val);
        startedAt = 0;
        updatedAt = block.timestamp;
        answeredInRound = 1; // = roundId
    }

    function latestAnswer() external view returns (int) {
        (uint256 val, /* goodOraclesCount */) = _read();

        return int(val);
    }
}
