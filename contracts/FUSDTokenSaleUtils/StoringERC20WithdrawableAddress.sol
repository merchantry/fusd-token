// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../openzeppelin/access/Ownable.sol";

abstract contract StoringERC20WithdrawableAddress is Ownable {
    address private erc20WithdrawableAddress;

    constructor(address _erc20WithdrawableAddress) {
        erc20WithdrawableAddress = _erc20WithdrawableAddress;
    }

    /**
     * @dev Returns the address to which the owner can withdraw
     * liquidated user collateral assets.
     */
    function getERC20WithdrawableAddress() public view returns (address) {
        return erc20WithdrawableAddress;
    }

    /**
     * @dev Allows the owner to set the withdrawal address.
     */
    function setERC20WithdrawableAddress(address _erc20WithdrawableAddress) external onlyOwner {
        erc20WithdrawableAddress = _erc20WithdrawableAddress;
    }
}
