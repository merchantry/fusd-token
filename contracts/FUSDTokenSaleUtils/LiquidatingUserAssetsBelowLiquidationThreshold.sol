// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DebtHandler.sol";
import "./CollateralRatioCalculator.sol";

abstract contract LiquidatingUserAssetsBelowLiquidationThreshold is DebtHandler, CollateralRatioCalculator, Ownable {
    mapping(address => bool) private debtorRegistered;
    address[] private debtors;

    /**
     * @dev Returns the liquidation threshold in percentage. If the collateral ratio
     * of a user is below this threshold, the user will be liquidated.
     * @return {uint256} liquidation threshold in percentage in 0.1%.
     */
    function getLiquidationThreshold() public view override returns (uint256) {
        return super.getLiquidationThreshold() + getAnnualInterestRateTenthPerc();
    }

    function registerDebtor(address debtor) internal {
        if (debtorRegistered[debtor]) return;

        debtors.push(debtor);
        debtorRegistered[debtor] = true;
    }

    /**
     * @dev Returns all users who have ever borrowed FUSD at some point.
     */
    function getAllDebtors() public view returns (address[] memory) {
        return debtors;
    }

    /**
     * @dev Returns all users who have outstanding debt.
     */
    function getCurrentDebtors() public view returns (address[] memory) {
        address[] memory allDebtors = getAllDebtors();
        address[] memory currentDebtors = new address[](allDebtors.length);
        uint256 currentDebtorsCount = 0;
        for (uint256 i = 0; i < allDebtors.length; i++) {
            address debtor = allDebtors[i];
            if (getTotalDebt(debtor) > 0) {
                currentDebtors[currentDebtorsCount] = debtor;
                currentDebtorsCount++;
            }
        }

        assembly {
            mstore(currentDebtors, currentDebtorsCount)
        }

        return currentDebtors;
    }

    /**
     * @dev Returns all users who have outstanding debt and are below the liquidation threshold.
     * All users who are below the liquidation threshold will be liquidated.
     */
    function getDebtorsBelowLiquidationThreshold() public view returns (address[] memory) {
        address[] memory allDebtors = getAllDebtors();
        address[] memory debtorsBelowLiquidationThreshold = new address[](allDebtors.length);
        uint256 debtorsBelowLiquidationThresholdCount = 0;
        for (uint256 i = 0; i < allDebtors.length; i++) {
            address debtor = allDebtors[i];
            if (isDebtorBelowLiquidationThreshold(debtor)) {
                debtorsBelowLiquidationThreshold[debtorsBelowLiquidationThresholdCount] = debtor;
                debtorsBelowLiquidationThresholdCount++;
            }
        }

        assembly {
            mstore(debtorsBelowLiquidationThreshold, debtorsBelowLiquidationThresholdCount)
        }

        return debtorsBelowLiquidationThreshold;
    }

    /**
     * @dev Allows the owner to liquidate all users who are below the liquidation threshold.
     */
    function liquidateAllDebtorsBelowLiquidationThreshold() public onlyOwner {
        address[] memory debtorsBelowLiquidationThreshold = getDebtorsBelowLiquidationThreshold();
        for (uint256 i = 0; i < debtorsBelowLiquidationThreshold.length; i++) {
            liquidateUser(debtorsBelowLiquidationThreshold[i]);
        }
    }

    function isDebtorBelowLiquidationThreshold(address debtor) public view virtual returns (bool);

    function liquidateUser(address user) internal virtual;
}
