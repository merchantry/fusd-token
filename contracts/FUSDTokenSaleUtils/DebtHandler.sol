// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

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

    function _addLoan(
        address user,
        uint256 amount,
        uint256 timestamp
    ) internal {
        debtChanges[user].push(DebtChange(amount, DebtAction.Loan, timestamp));
    }

    function _addRepayment(
        address user,
        uint256 amount,
        uint256 timestamp
    ) internal {
        debtChanges[user].push(DebtChange(amount, DebtAction.Repayment, timestamp));
    }

    /**
     * @dev Returns the debt changes for a user. The debt changes are sorted by timestamp.
     * The change can either be a loan or a repayment.
     */
    function getDebtChanges(address user) public view returns (DebtChange[] memory) {
        return debtChanges[user];
    }

    /**
     * @dev Returns the base debt and interest for a user. The base debt is the amount
     * of FUSD borrowed by the user. Interest is accrued each second on the base debt.
     * Each repayment lowers the interest first and then the base debt.
     */
    function calculateBaseDebtAndInterest(address user) public view returns (uint256, uint256) {
        DebtChange[] memory changes = debtChanges[user];
        uint256 baseDebt = 0;
        uint256 totalInterest = 0;
        uint256 lastChangeAt;

        for (uint256 i = 0; i < changes.length; i++) {
            DebtChange memory change = changes[i];

            if (baseDebt > 0) {
                totalInterest += calculateInterest(baseDebt, lastChangeAt, change.timestamp);
            }

            lastChangeAt = change.timestamp;

            if (change.action == DebtAction.Loan) {
                baseDebt += change.amount;
            } else if (change.action == DebtAction.Repayment) {
                uint256 amountToDeduct = change.amount;

                if (amountToDeduct >= totalInterest) {
                    amountToDeduct -= totalInterest;
                    totalInterest = 0;
                } else if (totalInterest > 0) {
                    totalInterest -= amountToDeduct;
                    amountToDeduct = 0;
                }

                baseDebt -= amountToDeduct;
            }
        }

        if (baseDebt > 0) {
            totalInterest += calculateInterest(baseDebt, lastChangeAt, time());
        }

        return (baseDebt, totalInterest);
    }

    /**
     * @dev Returns the total debt for a user. The total debt is the sum of the base debt
     * and the interest.
     */
    function getTotalDebt(address user) public view returns (uint256) {
        (uint256 base, uint256 interest) = calculateBaseDebtAndInterest(user);
        return base + interest;
    }
}
