// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FUSDTokenHandler.sol";

contract FUSDTokenSale is FUSDTokenHandler {
    constructor(address _fusdToken) FUSDTokenHandler(_fusdToken) Ownable(_msgSender()) {}

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
}
