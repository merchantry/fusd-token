// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

library ERC20Utils {
    /**
     * @dev Returns the token key by hashing the token symbol.
     */
    function getTokenKey(string memory tokenSymbol) internal pure returns (bytes32) {
        return keccak256(bytes(tokenSymbol));
    }
}
