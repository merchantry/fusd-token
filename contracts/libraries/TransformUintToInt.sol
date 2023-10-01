// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library TransformUintToInt {
    function toInt(uint8 x) internal pure returns (int16) {
        return int16(uint16(x));
    }
}
