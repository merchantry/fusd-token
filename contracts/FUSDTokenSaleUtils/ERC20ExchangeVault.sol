// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../FUSDToken.sol";
import "./TokenAdapterFactory.sol";
import "../libraries/ERC20Utils.sol";

abstract contract ERC20ExchangeVault is TokenAdapterFactory {
    mapping(address => mapping(bytes32 => uint256)) private userTokenBalances;

    function _depositToken(
        address user,
        string memory tokenSymbol,
        uint256 amount
    ) internal {
        userTokenBalances[user][ERC20Utils.getTokenKey(tokenSymbol)] += amount;
        ERC20(getTokenAdapter(tokenSymbol).getToken()).transferFrom(_msgSender(), address(this), amount);
    }

    function _withdrawToken(
        address user,
        string memory tokenSymbol,
        uint256 amount
    ) internal {
        bytes32 tokenKey = ERC20Utils.getTokenKey(tokenSymbol);
        require(userTokenBalances[user][tokenKey] >= amount, "ERC20ExchangeVault: insufficient balance");

        userTokenBalances[user][tokenKey] -= amount;
        ERC20(getTokenAdapter(tokenSymbol).getToken()).transfer(user, amount);
    }

    /**
     * @dev Returns the balance of the user for the specified token. Must provide a token with a valid adapter.
     * @param user Address of the user
     * @param tokenSymbol Symbol of the token
     */
    function getUserTokenBalance(address user, string memory tokenSymbol) public view returns (uint256) {
        return userTokenBalances[user][ERC20Utils.getTokenKey(tokenSymbol)];
    }

    /**
     * @dev Returns the balances of the user for all tokens.
     * @param user Address of the user
     * @return balances Array of balances. The index of each balance corresponds to the index of the symbol in the symbols array.
     * @return symbols Array of symbols. The index of each symbol corresponds to the index of the balance in the balances array.
     */
    function getUserTokenBalances(address user) public view returns (uint256[] memory, string[] memory) {
        TokenAdapterInterface[] memory tokenAdapters = getTokenAdapters();
        bytes32[] memory tokenKeys = getTokenKeys();

        uint256[] memory balances = new uint256[](tokenKeys.length);
        string[] memory symbols = new string[](tokenKeys.length);

        for (uint256 i = 0; i < tokenKeys.length; i++) {
            balances[i] = userTokenBalances[user][tokenKeys[i]];
            symbols[i] = ERC20(tokenAdapters[i].getToken()).symbol();
        }

        return (balances, symbols);
    }

    function withdrawAllUserAssetsToWithdrawable(address user, address withrawable) internal {
        TokenAdapterInterface[] memory tokenAdapters = getTokenAdapters();
        bytes32[] memory tokenKeys = getTokenKeys();

        for (uint256 i = 0; i < tokenKeys.length; i++) {
            uint256 tokenBalance = userTokenBalances[user][tokenKeys[i]];
            ERC20 token = ERC20(tokenAdapters[i].getToken());

            if (tokenBalance > 0) {
                token.transfer(withrawable, tokenBalance);
                userTokenBalances[user][tokenKeys[i]] = 0;
            }
        }
    }
}
