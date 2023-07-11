// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin/token/ERC20/ERC20.sol";
import "./TokenAdapterInterface.sol";
import "./openzeppelin/access/Ownable.sol";
import "./libraries/ERC20Utils.sol";

abstract contract TokenAdapterFactory is Ownable {
    mapping(bytes32 => TokenAdapterInterface) private tokenAdapters;
    bytes32[] private tokenKeys;

    modifier tokenAdapterExists(address token) {
        require(address(tokenAdapters[ERC20Utils.getTokenKey(token)]) != address(0), "Token adapter does not exist");
        _;
    }

    function getTokenKeys() internal view returns (bytes32[] memory) {
        return tokenKeys;
    }

    function getTokenAdapters() internal view returns (TokenAdapterInterface[] memory) {
        TokenAdapterInterface[] memory adapters = new TokenAdapterInterface[](tokenKeys.length);
        for (uint256 i = 0; i < tokenKeys.length; i++) {
            adapters[i] = tokenAdapters[tokenKeys[i]];
        }

        return adapters;
    }

    function getOracleValue(address token) internal view tokenAdapterExists(token) returns (uint128) {
        return tokenAdapters[ERC20Utils.getTokenKey(token)].getOracleValue();
    }

    function getOracleDecimals(address token) internal view returns (uint8) {
        return tokenAdapters[ERC20Utils.getTokenKey(token)].decimals();
    }

    /**
     * @dev Allows the owner to add a new token adapter.
     * There can be only one adapter per token symbol.
     * @param tokenAdapter Address of the token adapter
     */
    function addTokenAdapter(address tokenAdapter) public onlyOwner {
        TokenAdapterInterface tokenAdapterInstance = TokenAdapterInterface(tokenAdapter);
        bytes32 tokenKey = ERC20Utils.getTokenKey(tokenAdapterInstance.getToken());
        require(address(tokenAdapters[tokenKey]) == address(0), "Token adapter already exists");

        tokenAdapters[tokenKey] = tokenAdapterInstance;
        tokenKeys.push(tokenKey);
    }

    /**
     * @dev Returns addresses of all registered token adapters.
     */
    function getTokenAdapterAddresses() public view returns (address[] memory) {
        address[] memory adapters = new address[](tokenKeys.length);
        for (uint256 i = 0; i < tokenKeys.length; i++) {
            adapters[i] = address(tokenAdapters[tokenKeys[i]]);
        }

        return adapters;
    }

    /**
     * @dev Returns symbols of all registered tokens.
     */
    function getTokenSymbols() public view returns (string[] memory) {
        string[] memory symbols = new string[](tokenKeys.length);
        for (uint256 i = 0; i < tokenKeys.length; i++) {
            symbols[i] = ERC20(tokenAdapters[tokenKeys[i]].getToken()).symbol();
        }

        return symbols;
    }
}
