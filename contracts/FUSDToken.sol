// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin/token/ERC20/ERC20.sol";

contract FUSDToken is ERC20 {
    constructor() ERC20("FUSD Token", "FUSD") {}
}
