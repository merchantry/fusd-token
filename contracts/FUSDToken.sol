// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "./openzeppelin/token/ERC20/ERC20.sol";
import "./FUSDTokenUtils/FlaggingMinters.sol";
import "./layerzero/token/oft/v2/OFTV2.sol";

contract FUSDToken is OFTV2, FlaggingMinters {
    constructor(uint8 _sharedDecimals, address _lzEndpoint)
        OFTV2("FUSD Token", "FUSD", _sharedDecimals, _lzEndpoint)
        Ownable(_msgSender())
    {}

    function mint(address _to, uint256 _amount) public onlyMinters {
        _mint(_to, _amount);
    }

    function transferOwnership(address newOwner) public override(FlaggingMinters, Ownable) onlyOwner {
        super.transferOwnership(newOwner);
    }
}
