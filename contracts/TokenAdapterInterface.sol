// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface TokenAdapterInterface {
    function decimals() external view returns (uint8);

    function getOracle() external view returns (address);

    function getToken() external view returns (address);

    function getOracleValue() external view returns (uint128);
}
