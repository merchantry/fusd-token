// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../openzeppelin/access/Ownable.sol";

abstract contract FlaggingMinters is Ownable {
    mapping(address => bool) private _isMinter;

    constructor() {
        setIsMinter(_msgSender(), true);
    }

    modifier onlyMinters() {
        require(_isMinter[_msgSender()], "FlaggingMinters: caller is not a minter");
        _;
    }

    /**
     * @dev Overrides the transferOwnership function to set the new owner as a minter.
     */
    function transferOwnership(address newOwner) public override virtual onlyOwner {
        setIsMinter(newOwner, true);
        super.transferOwnership(newOwner);
    }

    /**
     * @dev Allows the owner to change the status of a minter.
     * @param minter Address of the minter to change status.
     * @param value True for minter, false for non-minter.
     */
    function setIsMinter(address minter, bool value) public onlyOwner {
        _isMinter[minter] = value;
    }

    /**
     * @dev Returns true if the address is a minter.
     * @param minter Address to check.
     */
    function isMinter(address minter) public view returns (bool) {
        return _isMinter[minter];
    }
}
