// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../DebtHandler.sol";

contract DebtHandlerTestContract is DebtHandler {
    constructor(
        uint16 _annualInterestRateTenthPerc
    ) InterestCalculator(_annualInterestRateTenthPerc) Ownable(_msgSender()) {}

    function addLoan(address user, uint256 amount, uint256 timestamp) public {
        _addLoan(user, amount, timestamp);
    }

    function addRepayment(address user, uint256 amount, uint256 timestamp) public {
        _addRepayment(user, amount, timestamp);
    }
}
