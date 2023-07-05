// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./InterestCalculator.sol";
import "./TimeHandler.sol";

abstract contract DebtHandler is InterestCalculator, TimeHandler {
    enum DebtAction {
        Loan,
        Repayment
    }

    struct DebtChange {
        uint256 amount;
        DebtAction action;
        uint256 timestamp;
    }

    mapping(address => DebtChange[]) private debtChanges;

    function _addLoan(address user, uint256 amount, uint256 timestamp) internal {
        debtChanges[user].push(DebtChange(amount, DebtAction.Loan, timestamp));
    }

    function _addRepayment(address user, uint256 amount, uint256 timestamp) internal {
        debtChanges[user].push(DebtChange(amount, DebtAction.Repayment, timestamp));
    }

    function getDebtChanges(address user) public view returns (DebtChange[] memory) {
        return debtChanges[user];
    }

    function calculateTotalLoanAndInterest(address user) public view returns (uint256, uint256) {
        DebtChange[] memory changes = debtChanges[user];
        uint256 totalLoan = 0;
        uint256 totalInterest = 0;
        uint256 lastChangeAt;

        for (uint256 i = 0; i < changes.length; i++) {
            DebtChange memory change = changes[i];

            if (totalLoan > 0) {
                totalInterest += calculateInterest(totalLoan, lastChangeAt, change.timestamp);
            }

            lastChangeAt = change.timestamp;

            if (change.action == DebtAction.Loan) {
                totalLoan += change.amount;
            } else if (change.action == DebtAction.Repayment) {
                uint256 amountToDeduct = change.amount;

                if (amountToDeduct >= totalInterest) {
                    amountToDeduct -= totalInterest;
                    totalInterest = 0;
                } else if (totalInterest > 0) {
                    totalInterest -= amountToDeduct;
                    amountToDeduct = 0;
                }

                totalLoan -= amountToDeduct;
            }
        }

        if (totalLoan > 0) {
            totalInterest += calculateInterest(totalLoan, lastChangeAt, time());
        }

        return (totalLoan, totalInterest);
    }
}
