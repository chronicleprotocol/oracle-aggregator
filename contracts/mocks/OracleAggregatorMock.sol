// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IChronicle} from "../IChronicle.sol";
import {OracleAggregator} from "../OracleAggregator.sol";

contract OracleAggregatorMock is OracleAggregator {
    error UnathorisedDataConsumer(address consumer);

    IChronicle internal _chronicle;
    AggregatorV3Interface internal _chainlink;
    AggregatorV3Interface internal _redstone;
    address internal _authorisedConsumer;
    uint32 internal _ageThreshold;
    uint256 internal _price;

    constructor(AggregatorV3Interface __chainlink, IChronicle __chronicle, AggregatorV3Interface __redstone, uint32 __ageThreshold, address __authorisedConsumer) {
        _chainlink = __chainlink;
        _chronicle = __chronicle;
        _redstone = __redstone;
        _ageThreshold = __ageThreshold;
        _authorisedConsumer = __authorisedConsumer;
    }

    function readOracleForGasBenchmark() external {
        (_price,) = getAggregatedOracleValue();
    }

    function description() public view virtual override returns (string memory) {
        return "Mock Oracle Aggregator for tests";
    }
    
    function chronicle() public view virtual override returns(IChronicle) {
        return _chronicle;
    }

    function chainlink() public view virtual override returns(AggregatorV3Interface) {
        return _chainlink;
    }

    function redstone() public view virtual override returns(AggregatorV3Interface) {
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
