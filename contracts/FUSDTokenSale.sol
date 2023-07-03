// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FUSDToken.sol";
import "./ERC20ExchangeVault.sol";
import "./libraries/Math.sol";

contract FUSDTokenSale is ERC20ExchangeVault {
    FUSDToken private fusdToken;

    constructor(address _fusdToken) Ownable(_msgSender()) {
        fusdToken = FUSDToken(_fusdToken);
    }

    /**
     * temporary function to deposit ERC20 tokens
     * TODO: remove this function
     */
    function deposit(address token, uint256 amount) public {
        depositToken(_msgSender(), token, amount);
    }

    /**
     * temporary function to withdraw ERC20 tokens
     * TODO: remove this function
     */
    function withdraw(address token, uint256 amount) public {
        withdrawToken(_msgSender(), token, amount);
    }

    /**
     * @dev Calculates the price of the token in FUSD.
     * Must provide a token with a valid adapter, otherwise reverts.
     * @param token Address of the token. Must have a valid adapter.
     * @param amount Amount of the token
     */
    function tokenPriceInFUSD(address token, uint256 amount) public view returns (uint256) {
        uint128 priceInUsd = getOracleValue(token);
        int16 usdPriceDecimals = int16(uint16(getOracleDecimals(token)));
        int16 tokenDecimals = int16(uint16(ERC20(token).decimals()));
        int16 fusdDecimals = int16(uint16(fusdToken.decimals()));

        return Math.multiplyByTenPow(amount * priceInUsd, fusdDecimals - usdPriceDecimals - tokenDecimals);
    }
}
