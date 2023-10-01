// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./openzeppelin/token/ERC20/ERC20.sol";
import "./FUSDTokenUtils/FlaggingMinters.sol";

contract FUSDToken is ERC20, FlaggingMinters {
    constructor() ERC20("FUSD Token", "FUSD") Ownable(_msgSender()) {}

    function mint(address _to, uint256 _amount) public onlyMinters {
        _mint(_to, _amount);
    }
}
