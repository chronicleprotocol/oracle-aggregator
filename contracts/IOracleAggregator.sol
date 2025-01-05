// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IOracleAggregator {
    // -- Immutable Configurations --

    // -- Oracles

    /// @notice Returns the Chronicle oracle.
    /// @return chronicle The Chronicle oracle address.
    function chronicle() external view returns (address chronicle);

    /// @notice Returns the Chainlink oracle.
    /// @return chainlink The Chainlink oracle address.
    function chainlink() external view returns (address chainlink);

    /// @notice Returns the Redstone oracle.
    /// @return redstone The Redstone oracle address.
    function redstone() external view returns (address redstone);
}
