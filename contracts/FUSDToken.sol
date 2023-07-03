// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin/token/ERC20/ERC20.sol";
import "./openzeppelin/access/Ownable.sol";

contract FUSDToken is ERC20, Ownable {
    constructor() ERC20("FUSD Token", "FUSD") Ownable(_msgSender()) {}

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
