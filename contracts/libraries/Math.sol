// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library Math {
    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }

    /**
     * @dev Multiplies n by 10^exponent. Exponent can be negative, in which case it will divide n
     * by 10^|exponent|.
     */
    function multiplyByTenPow(uint256 n, int256 exponent) internal pure returns (uint256) {
        uint256 absoluteExponent = abs(exponent);
        if (exponent < 0) {
            return n / 10**absoluteExponent;
        }

        return n * 10**absoluteExponent;
    }
}
