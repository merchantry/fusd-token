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

    // user => debt session => debt changes
    mapping(address => DebtChange[][]) private debtChanges;

    /**
     * The maximum number of debt changes per debt session. This is to prevent
     * users from racking up too many debt changes in a single session. To
     * process a debt repayment, we have to calculate the current debt of the user,
     * which means we have to iterate over all current debt changes. This can be
     * expensive if the number of debt changes is very high. If the cost
     * becomes too high, there is a chance that the transaction will run out of
     * gas and fail.
     *
     * Here is some data from testing the gas cost of processing a debt repayment
     * through the `payOffAllDebt` function in the `FUSDTokenSale` contract. We
     * tested the gas cost for different numbers of debt changes. For every 2 debt
     * changes, one is a loan and the other is a repayment:
     *
     * Number of debt changes | Gas cost in units
     * -----------------------|---------
     * 10                     |  258,043
     * 50                     |  707,560
     * 100                    |  1,270,017
     * 250                    |  2,961,141
     * 500                    |  5,792,180
     * 1000                   |  11,501,133
     */
    uint256 private constant DEBT_CHANGES_LIMIT = 400;

    modifier belowDebtChangesLimit(address user) {
        require(getNumOfCurrentDebtChanges(user) < DEBT_CHANGES_LIMIT, "DebtHandler: Debt changes limit reached");
        _;
    }

    function addNewDebtChange(address user, DebtChange memory change) private {
        uint256 lastChangeIndex = debtChanges[user].length - 1;
        debtChanges[user][lastChangeIndex].push(change);
    }

    function _addLoan(
        address user,
        uint256 amount,
        uint256 timestamp
    ) internal {
        addNewDebtChange(user, DebtChange(amount, DebtAction.Loan, timestamp));
    }

    function _addRepayment(
        address user,
        uint256 amount,
        uint256 timestamp
    ) internal {
        addNewDebtChange(user, DebtChange(amount, DebtAction.Repayment, timestamp));
    }

    function _addNewDebtSession(address user) internal {
        debtChanges[user].push();
    }

    /**
     * @dev Returns all debt changes for a user. This includes debt changes from
     * previous sessions. The debt changes are sorted by timestamp. The change
     * can either be a loan or a repayment.
     */
    function getAllDebtChanges(address user) external view returns (DebtChange[][] memory) {
        return debtChanges[user];
    }

    /**
     * @dev Returns the debt changes for a user from the most recent session.
     * If the user has previously build up debt and repaid it in full afterwards,
     * changes from that period up until the point the debt was repaid will not be
     * returned by this function. The debt changes are sorted by timestamp.
     * The change can either be a loan or a repayment.
     */
    function getCurrentDebtChanges(address user) public view returns (DebtChange[] memory) {
        if (debtChanges[user].length == 0) {
            return new DebtChange[](0);
        }
        uint256 lastChangeIndex = debtChanges[user].length - 1;
        return debtChanges[user][lastChangeIndex];
    }

    /**
     * @dev Returns the number of debt changes for a user from the most recent session.
     */
    function getNumOfCurrentDebtChanges(address user) public view returns (uint256) {
        return getCurrentDebtChanges(user).length;
    }

    /**
     * @dev Returns the base debt and interest for a user. The base debt is the amount
     * of FUSD borrowed by the user. Interest is accrued each second on the base debt.
     * Each repayment lowers the interest first and then the base debt.
     */
    function calculateBaseDebtAndInterest(address user) public view returns (uint256, uint256) {
        DebtChange[] memory changes = getCurrentDebtChanges(user);
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
