// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin/access/Ownable.sol";

abstract contract StoringERC20WithdrawableAddress is Ownable {
    address private erc20WithdrawableAddress;

    constructor(address _erc20WithdrawableAddress) {
        erc20WithdrawableAddress = _erc20WithdrawableAddress;
    }

    function getERC20WithdrawableAddress() public view returns (address) {
        return erc20WithdrawableAddress;
    }

    function setERC20WithdrawableAddress(address _erc20WithdrawableAddress) public onlyOwner {
        erc20WithdrawableAddress = _erc20WithdrawableAddress;
    }
}
