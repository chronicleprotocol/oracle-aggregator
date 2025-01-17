// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library NumericArrayLib {
  uint256 constant UINT256_SHIFT = 5; // 2 ** 5 == 32
  uint256 constant BYTES_ARR_LEN_VAR_BS = 32;
  uint256 constant UINT256_VALUE_BS = 32;

  error CanNotPickMedianOfEmptyArray();

  // This function modifies the array if it has more than 3 elements
  // We handle cases for up to 3 elements manually to optimise gas cost (~700 gas)
  function pickMedian(uint256[] memory arr) internal pure returns (uint256) {
    if (arr.length == 3) {
      if (arr[0] < arr[1]) {
        if (arr[1] < arr[2]) {
          return arr[1]; // arr[0] < arr[1] < arr[2]
        } else {
          return arr[0] > arr[2] ? arr[0] : arr[2];
        }
      } else { // arr[0] >= arr[1]
        if (arr[0] < arr[2]) {
          return arr[0]; // arr[1] <= arr[0] < arr[2]
        } else {
          return arr[1] > arr[2] ? arr[1] : arr[2];
        }
      }
    }

    if (arr.length == 2) return (arr[0] + arr[1]) / 2;
    if (arr.length == 1) return arr[0];
    if (arr.length == 0) revert CanNotPickMedianOfEmptyArray();

    // For arr.length > 3
    sort(arr);
    uint256 middleIndex = arr.length / 2;
    if (arr.length % 2 == 0) {
      uint256 sum = arr[middleIndex - 1] + arr[middleIndex];
      return sum / 2;
    } else {
      return arr[middleIndex];
    }
  }

  // This function sorts an array in memory using a simple sort algorithm,
  // which performs even better than quick sort for small arrays
  function sort(uint256[] memory arr) internal pure {
    assembly {
      let arrLength := mload(arr)
      let valuesPtr := add(arr, BYTES_ARR_LEN_VAR_BS) // memory location of arr[0]
      let endPtr := add(valuesPtr, shl(UINT256_SHIFT, arrLength)) // shl(UINT256_SHIFT, arrLength) == UINT256_VALUE_BS * arrLength
      for {
        let arrIPtr := add(valuesPtr, UINT256_VALUE_BS) // starting from arr[1]
      } lt(arrIPtr, endPtr) {
        arrIPtr := add(arrIPtr, UINT256_VALUE_BS) // arrIPtr += 32
      } {
        for {
          let arrJPtr := valuesPtr
        } lt(arrJPtr, arrIPtr) {
          arrJPtr := add(arrJPtr, UINT256_VALUE_BS) // arrJPtr += 32
        } {
          let arrI := mload(arrIPtr)
          let arrJ := mload(arrJPtr)
          if lt(arrI, arrJ) {
            mstore(arrIPtr, arrJ)
            mstore(arrJPtr, arrI)
          }
        }
      }
    }
  }
}
