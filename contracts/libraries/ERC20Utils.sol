// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../openzeppelin/token/ERC20/ERC20.sol";

library ERC20Utils {
    /**
     * @dev Returns the token key by hashing the token symbol.
     */
    function getTokenKey(address token) internal view returns (bytes32) {
        return keccak256(bytes(ERC20(token).symbol()));
    }
}
