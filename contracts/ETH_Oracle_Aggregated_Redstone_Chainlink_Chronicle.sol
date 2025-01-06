// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {OracleAggregator} from "./OracleAggregator.sol";

contract ETH_Oracle_Aggregated_Chronicle_Chainlink_Redstone is OracleAggregator {
    error UnathorisedDataConsumer(address consumer);

    function description() public view virtual override returns (string memory) {
        return "Aggregated price feed ETH/USD from Chronicle, Chainlink, and RedStone";
    }
    
    function chronicle() public pure virtual override returns(address) {
        return 0x46ef0071b1E2fF6B42d36e5A177EA43Ae5917f4E;
    }

    function chainlink() public pure virtual override returns(address) {
        return 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    }

    function redstone() public pure virtual override returns(address) {
        // TODO: change to ETH Price Feed, currently it's weETH/ETH feed
        return 0x8751F736E94F6CD167e8C5B97E245680FbD9CC36;
    }

    function checkAuthorisedDataConsumer(address consumer) public pure virtual override {
        if (consumer != address(0) && consumer != 0x8105f69D9C41644c6A0803fDA7D03Aa70996cFD9) {
            revert UnathorisedDataConsumer(consumer);
        }
    }

    function getAgeThreshold() public pure virtual override returns(uint32) {
        return 25 days;
    }

}
