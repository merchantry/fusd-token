// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./openzeppelin/token/ERC20/ERC20.sol";
import "./openzeppelin/access/Ownable.sol";
import "./oracles/DIAOracleV2.sol";
import "./TokenAdapterUtils/TokenAdapterInterface.sol";
import "./TokenAdapterUtils/TokenAdapter.sol";

contract DIAOracleV2TokenAdapter is Ownable, TokenAdapter, TokenAdapterInterface {
    DIAOracleV2 private oracle;

    constructor(address _oracle, address token)
        oracleTracksToken(_oracle, token)
        Ownable(_msgSender())
        TokenAdapter(token)
    {
        oracle = DIAOracleV2(_oracle);
    }

    modifier oracleTracksToken(address _oracle, address token) {
        (uint128 value, uint128 timestamp) = DIAOracleV2(_oracle).getValue(getOracleTokenKey());
        require(value != 0 && timestamp != 0, "Token adapter: invalid oracle value");
        _;
    }

    function getOracleTokenKey() private view returns (string memory) {
        return string(abi.encodePacked(ERC20(getToken()).symbol(), "/", "USD"));
    }

    /**
     * @dev Allows the owner to update the oracle address. Oracle must have a value for the token.
     * @param _oracle Address of the oracle
     */
    function updateOracle(address _oracle) external onlyOwner oracleTracksToken(_oracle, getToken()) {
        oracle = DIAOracleV2(_oracle);
    }

    /**
     * @dev Allows the owner to update the token address. New token must have the same symbol as the old one.
     * @param token Address of the token
     */
    function updateToken(address token) public onlyOwner {
        super._updateToken(token);
    }

    /**
     * @dev DIAOracleV2 always returns a value with 8 decimals.
     */
    function decimals() public pure returns (uint8) {
        return 8;
    }

    function getOracle() external view returns (address) {
        return address(oracle);
    }

    function getToken() public view returns (address) {
        return super._getToken();
    }

    /**
     * @dev Returns the current value of the token in USD.
     */
    function getOracleValue() public view returns (uint128) {
        (uint128 tokenValue, ) = oracle.getValue(getOracleTokenKey());
        return tokenValue;
    }
}
