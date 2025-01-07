// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {OracleAggregator} from "../OracleAggregator.sol";

contract OracleAggregatorMock is OracleAggregator {
    error UnathorisedDataConsumer(address consumer);

    address internal _chainlink;
    address internal _chronicle;
    address internal _redstone;
    address internal _authorisedConsumer;
    uint32 internal _ageThreshold;

    constructor(address __chainlink, address __chronicle, address __redstone, uint32 __ageThreshold, address __authorisedConsumer) {
        _chainlink = __chainlink;
        _chronicle = __chronicle;
        _redstone = __redstone;
        _ageThreshold = __ageThreshold;
        _authorisedConsumer = __authorisedConsumer;
    }

    function description() public view virtual override returns (string memory) {
        return "Mock Oracle Aggregator for tests";
    }
    
    function chronicle() public view virtual override returns(address) {
        return _chronicle;
    }

    function chainlink() public view virtual override returns(address) {
        return _chainlink;
    }

    function redstone() public view virtual override returns(address) {
        return _redstone;
    }

    function checkAuthorisedDataConsumer(address consumer) public view virtual override {
        if (_authorisedConsumer == address(0)) {
            // If not set, then allow everyone to read
            return;
        }

        // Otherwise verify
        if (consumer != _authorisedConsumer) {
            revert UnathorisedDataConsumer(consumer);
        }
    }

    function getAgeThreshold() public view virtual override returns(uint32) {
        return _ageThreshold;
    }

}
