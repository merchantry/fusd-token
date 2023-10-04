// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "../openzeppelin/access/Ownable.sol";
import "../TokenAdapterUtils/TokenAdapterInterface.sol";
import "../libraries/ERC20Utils.sol";

abstract contract TokenAdapterFactory is Ownable {
    mapping(bytes32 => TokenAdapterInterface) private tokenAdapters;
    bytes32[] private tokenKeys;

    function getTokenAdapter(string memory tokenSymbol) internal view returns (TokenAdapterInterface) {
        bytes32 tokenKey = ERC20Utils.getTokenKey(tokenSymbol);
        require(address(tokenAdapters[tokenKey]) != address(0), "Token adapter does not exist");

        return tokenAdapters[tokenKey];
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

    function getOracleValue(string memory tokenSymbol) internal view returns (uint128) {
        return getTokenAdapter(tokenSymbol).getOracleValue();
    }

    function getOracleDecimals(string memory tokenSymbol) internal view returns (uint8) {
        return getTokenAdapter(tokenSymbol).decimals();
    }

    /**
     * @dev Allows the owner to add a new token adapter.
     * There can be only one adapter per token symbol.
     * @param tokenAdapter Address of the token adapter
     */
    function addTokenAdapter(address tokenAdapter) external onlyOwner {
        TokenAdapterInterface tokenAdapterInstance = TokenAdapterInterface(tokenAdapter);
        bytes32 tokenKey = ERC20Utils.getTokenKey(ERC20(tokenAdapterInstance.getToken()).symbol());
        require(address(tokenAdapters[tokenKey]) == address(0), "Token adapter already exists");

        tokenAdapters[tokenKey] = tokenAdapterInstance;
        tokenKeys.push(tokenKey);
    }

    /**
     * @dev Returns addresses of all registered token adapters.
     */
    function getTokenAdapterAddresses() external view returns (address[] memory) {
        address[] memory adapters = new address[](tokenKeys.length);
        for (uint256 i = 0; i < tokenKeys.length; i++) {
            adapters[i] = address(tokenAdapters[tokenKeys[i]]);
        }

        return adapters;
    }

    /**
     * @dev Returns symbols of all registered tokens.
     */
    function getTokenSymbols() external view returns (string[] memory) {
        string[] memory symbols = new string[](tokenKeys.length);
        for (uint256 i = 0; i < tokenKeys.length; i++) {
            symbols[i] = ERC20(tokenAdapters[tokenKeys[i]].getToken()).symbol();
        }

        return symbols;
    }
}
