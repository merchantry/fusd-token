// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract TimeHandler {
    function time() internal view returns (uint256) {
        return block.timestamp;
    }
}
