// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../FUSDTokenSaleUtils/DebtHandler.sol";

contract DebtHandlerTestContract is DebtHandler {
    constructor(uint16 _annualInterestRateTenthPerc) InterestCalculator(_annualInterestRateTenthPerc) {}

    function addNewDebtSession(address user) public {
        _addNewDebtSession(user);
    }

    function addLoan(
        address user,
        uint256 amount,
        uint256 timestamp
    ) public {
        _addLoan(user, amount, timestamp);
    }

    function addRepayment(
        address user,
        uint256 amount,
        uint256 timestamp
    ) public {
        _addRepayment(user, amount, timestamp);
    }
}
