// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IOracleAggregator {

    function getAggregatedOracleValue() external view returns (uint256 value, uint8 goodOraclesCount);

    // Immutable Configurations

    function chronicle() external view returns (address chronicle);
    function chainlink() external view returns (address chainlink);
    function redstone() external view returns (address redstone);
    function checkAuthorisedDataConsumer(address consumer) external pure;

}
