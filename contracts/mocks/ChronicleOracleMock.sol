// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {IChronicle} from "../IChronicle.sol";

contract ChronicleOracleMock is IChronicle {
    error ZeroValueIsInvalid();

    uint8 internal constant _DECIMALS_CHRONICLE_MINUS_CHAINLINK = 10;

    uint256 private _value;
    uint256 private _age;
    bool private _valueSet;
    bool private _gasConsumingModeEnabled;

    // Set the value and age for the mock oracle
    function setValue(uint256 value, uint256 age) external {
        _value = value;
        _age = age;
        _valueSet = true;
    }

    function enableGasConsumingMode() external {
        _gasConsumingModeEnabled = true;
    }

    // Mock implementation of tryReadWithAge
    function tryReadWithAge() external view override returns (bool isValid, uint256 value, uint age256) {
        if (_gasConsumingModeEnabled) {
            bytes32[] memory arr = new bytes32[](1000000);
        }

        if (_valueSet) {
            if (_value == 0) {
                revert ZeroValueIsInvalid();
            } else {
                return (true, _value * (10 ** _DECIMALS_CHRONICLE_MINUS_CHAINLINK), _age);
            }
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
