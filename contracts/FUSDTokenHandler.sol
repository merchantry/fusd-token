// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FUSDToken.sol";
import "./ERC20ExchangeVault.sol";
import "./libraries/Math.sol";
import "./libraries/TransformUintToInt.sol";

abstract contract FUSDTokenHandler is ERC20ExchangeVault {
    using TransformUintToInt for uint8;

    FUSDToken private fusdToken;

    constructor(address _fusdToken) {
        fusdToken = FUSDToken(_fusdToken);
    }

    function mintFUSD(address user, uint256 amount) internal {
        fusdToken.mint(user, amount);
    }

    function transferFUSD(
        address from,
        address to,
        uint256 amount
    ) internal {
        fusdToken.transferFrom(from, to, amount);
    }

    /**
     * @dev Calculates the price of the token in FUSD.
     * Must provide a token with a valid adapter, otherwise reverts.
     * @param token Address of the token. Must have a valid adapter.
     * @param amount Amount of the token
     */
    function tokenPriceInFUSD(address token, uint256 amount) public view returns (uint256) {
        uint128 priceInUsd = getOracleValue(token);
        int16 usdPriceDecimals = getOracleDecimals(token).toInt();
        int16 tokenDecimals = ERC20(token).decimals().toInt();
        int16 fusdDecimals = fusdToken.decimals().toInt();

        return Math.multiplyByTenPow(amount * priceInUsd, fusdDecimals - usdPriceDecimals - tokenDecimals);
    }

    /**
     * @dev Returns the total worth of all collateral tokens currently deposited by the user
     * in FUSD. The worth of each token is calculated using the token's price in FUSD.
     * @param user Address of the user to calculate the collateral worth for
     */
    function getUserCollateralWorthInFUSD(address user) public view returns (uint256) {
        TokenAdapterInterface[] memory tokenAdapters = getTokenAdapters();
        bytes32[] memory tokenKeys = getTokenKeys();

        uint256 collateralWorth = 0;

        for (uint256 i = 0; i < tokenKeys.length; i++) {
            address tokenAddress = tokenAdapters[i].getToken();
            uint256 tokenBalance = getUserTokenBalance(user, tokenAddress);
            if (tokenBalance > 0) {
                collateralWorth += tokenPriceInFUSD(tokenAddress, tokenBalance);
            }
        }

        return collateralWorth;
    }
}
