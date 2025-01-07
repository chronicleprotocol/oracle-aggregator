// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {NumericArrayLib} from "@redstone-finance/evm-connector/contracts/libs/NumericArrayLib.sol";
import {IChronicle} from "./IChronicle.sol";
import {IOracleAggregator} from "./IOracleAggregator.sol";

abstract contract OracleAggregator is AggregatorV3Interface, IOracleAggregator {
    // Decimals used by Chronicle
    uint8 internal constant _DECIMALS_CHRONICLE = 18;
    uint256 internal constant _GAS_LIMIT_PER_ORACLE_READ = 100_000;
    uint256 internal constant _LATEST_ROUND_DATA_RETURN_SIZE = 160;
    uint256 internal constant _TRY_READ_WITH_AGE_RETURN_SIZE = 96;

    uint8 public constant decimals = 8;

    function chronicle() public view virtual returns(address);
    function chainlink() public view virtual returns(address);
    function redstone() public view virtual returns(address);
    function checkAuthorisedDataConsumer(address consumer) public view virtual;
    function getAgeThreshold() public view virtual returns(uint32);

    function getAggregatedOracleValue() public view returns (uint256 value, uint8 goodOraclesCount) {
        (bool okChr, uint256 valChr) = _safeReadFromChronicle();
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

        if (success && returnData.length == _LATEST_ROUND_DATA_RETURN_SIZE) {
            (/* roundId */, int256 answer, /* startedAt */, uint256 updatedAt, /* answeredInRound */) =
                abi.decode(returnData, (uint80, int256, uint256, uint256, uint80));

            bool isStale;
            unchecked {
                isStale = updatedAt + getAgeThreshold() < block.timestamp;
            }

            if (isStale || answer <= 0 || uint(answer) > uint(type(uint128).max)) {
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

        if (callSuccess && returnData.length == _TRY_READ_WITH_AGE_RETURN_SIZE) {
            (bool isValid, uint256 value, uint256 age) = abi.decode(returnData, (bool, uint256, uint256));

            bool isStale;
            unchecked {
                isStale = age + getAgeThreshold() < block.timestamp;
            }

            if (!isValid || isStale) {
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
            uint startedAt,
            uint updatedAt,
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
        revert();
    }

    function getRoundData(uint80 /* requestedRoundId */) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert();
    }

    function version() external virtual pure override returns (uint256) {
        return 1;
    }
}
