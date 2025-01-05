// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {NumericArrayLib} from "@redstone-finance/evm-connector/contracts/libs/NumericArrayLib.sol";
import {IChronicle} from "./IChronicle.sol";
import {IOracleAggregator} from "./IOracleAggregator.sol";

// Open questions:
// - How can we ensure that chronicle will toll our contract
// - Should we be able to change the ageThreshold

abstract contract OracleAggregator is AggregatorV3Interface, IOracleAggregator {
    /// @dev The decimals value used by Chronicle Protocol oracles.
    uint8 internal constant _DECIMALS_CHRONICLE = 18;

    uint32 public constant ageThreshold = 2 days;
    uint8 public constant decimals = 8;

    /// @inheritdoc IOracleAggregator
    address public immutable chronicle;
    /// @inheritdoc IOracleAggregator
    address public immutable chainlink;
    /// @inheritdoc IOracleAggregator
    address public immutable redstone;

    constructor(address chronicle_, address chainlink_, address redstone_) payable {
        chronicle = chronicle_;
        chainlink = chainlink_;
        redstone = redstone_;
    }

    function _read() internal view returns (uint256 value, uint8 goodOraclesCount) {
        (bool okChr, uint256 valChr) = _readChronicle();
        (bool okChl, uint256 valChl) = _readFromAggregatorV3Interface(chainlink);
        (bool okRed, uint256 valRed) = _readFromAggregatorV3Interface(redstone);

        uint256 index = 0;
        goodOraclesCount = (okChr ? 1 : 0) + (okChl ? 1 : 0) + (okRed ? 1 : 0);
        uint256[] memory values = new uint256[](goodOraclesCount);

        if (okChr) values[index++] = valChr;
        if (okChl) values[index++] = valChl;
        if (okRed) values[index++] = valRed;

        value = NumericArrayLib.pickMedian(values);
    }

    // TODO: modify this function to avoid issues with code rights
    // TODO: implement the low-level solution with tests
    function _readFromAggregatorV3Interface(address priceFeed) internal view returns (bool, uint256) {
        // !!! IMPORTANT WARNING !!!
        //
        // This function implementation MUST NOT be used when the Chainlink
        // oracle's implementation is behind a proxy!
        //
        // Otherwise a malicious contract update is possible via which every
        // read will fail. Note that this vulnerability _cannot_ be fixed via
        // using try-catch as of version 0.8.24. This is because the abi.decoding
        // of the return data is "outside" the try-block.
        //
        // The only way to fully protect against malicious contract updates is
        // via using a low-level staticcall with _manual_ returndata decoding!
        //
        // Note that the trust towards Chainlink not performing a malicious
        // contract update is different from the trust to not maliciously update
        // the oracle's configuration. While the latter can lead to invalid and
        // malicious price updates, the first may lead to a total
        // denial-of-service for protocols reading the proxy.

        try AggregatorV3Interface(priceFeed).latestRoundData() returns (
            uint80, /*roundId*/
            int answer,
            uint, /*startedAt*/
            uint updatedAt,
            uint80 /*answeredInRound*/
        ) {
            // Decide whether value is stale.
            // Unchecked to circumvent revert due to overflow. Overflow otherwise
            // no issue as updatedAt is solely controlled by Chainlink anyway.
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

            // Otherwise ok.
            return (true, uint128(uint(answer)));
        } catch {
            return (false, 0);
        }
    }



    // TODO: modify this function to avoid issues with code rights
    function _readChronicle() internal view returns (bool, uint256) {
        // Note that Chronicle's `try...` functions revert iff the caller is not
        // toll'ed.
        try IChronicle(chronicle).tryReadWithAge() returns (
            bool ok, uint val, uint age
        ) {
            // assert(val <= type(uint128).max);
            // assert(!ok || val != 0); // ok -> val != 0
            // assert(age <= block.timestamp);

            // Fail if not ok or value stale.
            if (!ok || age + ageThreshold < block.timestamp) {
                return (false, 0);
            }

            // Scale value down from Chronicle decimals to Aggor decimals.
            // assert(_DECIMALS_CHRONICLES >= decimals).
            val /= 10 ** (_DECIMALS_CHRONICLE - decimals);

            return (true, val);
        } catch {
            // assert(!IToll(chronicle).tolled(address(this)));
            return (false, 0);
        }
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
