// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "./InterestCalculator.sol";

abstract contract CollateralRatioCalculator {
    uint256 private minCollateralRatioForLoanTenthPerc;
    uint256 private liquidationPenaltyTenthPerc;

    constructor(uint256 _minCollateralRatioForLoanTenthPerc, uint256 _liquidationPenaltyTenthPerc) {
        minCollateralRatioForLoanTenthPerc = _minCollateralRatioForLoanTenthPerc;
        liquidationPenaltyTenthPerc = _liquidationPenaltyTenthPerc;
    }

    /**
     * @dev Returns the minimum collateral ratio required for a loan in 0.1%.
     * The user must have at least this much collateral to borrow FUSD. Also the
     * user's collateral ratio must be at least this much after borrowing FUSD.
     */
    function getMinCollateralRatioForLoanTenthPerc() public view returns (uint256) {
        return minCollateralRatioForLoanTenthPerc;
    }

    function setMinCollateralRatioForLoanTenthPerc(uint256 _minCollateralRatioForLoanTenthPerc) public virtual {
        minCollateralRatioForLoanTenthPerc = _minCollateralRatioForLoanTenthPerc;
    }

    /**
     * @dev Returns the liquidation penalty in 0.1%. The liquidation penalty
     * is used to calculate the liquidation threshold
     */
    function getLiquidationPenaltyTenthPerc() public view returns (uint256) {
        return liquidationPenaltyTenthPerc;
    }

    function setLiquidationPenaltyTenthPerc(uint256 _liquidationPenaltyTenthPerc) public virtual {
        liquidationPenaltyTenthPerc = _liquidationPenaltyTenthPerc;
    }

    /**
     * @dev Returns the collateral ratio in 0.1%.
     */
    function calculateCollateralRatio(uint256 collateralWorthInFUSD, uint256 totalDebt)
        internal
        pure
        returns (uint256)
    {
        require(totalDebt > 0, "CollateralRatioCalculator: Total debt must be greater than 0");

        return (collateralWorthInFUSD * 1000) / totalDebt;
    }

    /**
     * @dev Checks if the collateral ratio is safe for a loan. If the function returns false,
     * the user should not be allowed to borrow FUSD.
     */
    function isCollateralRatioSafe(uint256 collateralWorthInFUSD, uint256 totalDebt) internal view returns (bool) {
        if (totalDebt == 0) return true;
        return calculateCollateralRatio(collateralWorthInFUSD, totalDebt) >= minCollateralRatioForLoanTenthPerc;
    }

    function getLiquidationThreshold() public view virtual returns (uint256) {
        return 1000 + liquidationPenaltyTenthPerc;
    }
}
