// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IChronicle} from "../IChronicle.sol";

// TODO: adjust for testing OOG attacks
// TODO: adjust for reverting

contract ChronicleOracleMock is IChronicle {
    uint8 internal constant _DECIMALS_CHRONICLE_MINUS_CHAINLINK = 10;

    uint256 private _value;
    uint256 private _age;
    bool private _valueSet;

    // Set the value and age for the mock oracle
    function setValue(uint256 value, uint256 age) external {
        _value = value;
        _age = age;
        _valueSet = true;
    }

    // Mock implementation of tryReadWithAge
    function tryReadWithAge() external view override returns (bool isValid, uint256 value, uint age256) {
        if (_valueSet) {
            return (true, _value * (10 ** _DECIMALS_CHRONICLE_MINUS_CHAINLINK), _age);
        } else {
            return (false, 0, 0);
        }
    }

    // Other functions revert as they are not implemented
    function wat() external pure override returns (bytes32) {
        revert();
    }

    function read() external pure override returns (uint) {
        revert();
    }

    function readWithAge() external pure override returns (uint, uint) {
        revert();
    }

    function tryRead() external pure override returns (bool, uint) {
        revert();
    }
}
