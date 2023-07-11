// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./InterestCalculator.sol";

abstract contract CollateralRatioCalculator is Ownable {
    uint256 private minCollateralRatioForLoanPerc;
    uint256 private liquidationPenaltyPerc;

    constructor(uint256 _minCollateralRatioForLoanPerc, uint256 _liquidationPenaltyPerc) {
        minCollateralRatioForLoanPerc = _minCollateralRatioForLoanPerc;
        liquidationPenaltyPerc = _liquidationPenaltyPerc;
    }

    /**
     * @dev Returns the minimum collateral ratio required for a loan in percentage.
     * The user must have at least this much collateral to borrow FUSD. Also the
     * user's collateral ratio must be at least this much after borrowing FUSD.
     */
    function getMinCollateralRatioForLoanPerc() public view returns (uint256) {
        return minCollateralRatioForLoanPerc;
    }

    /**
     * @dev Allows owner to set the minimum collateral ratio required for a loan in percentage.
     */
    function setMinCollateralRatioForLoanPerc(uint256 _minCollateralRatioForLoanPerc) public onlyOwner {
        minCollateralRatioForLoanPerc = _minCollateralRatioForLoanPerc;
    }

    /**
     * @dev Returns the liquidation penalty in percentage. The liquidation penalty
     * is used to calculate the liquidation threshold
     */
    function getLiquidationPenaltyPerc() public view returns (uint256) {
        return liquidationPenaltyPerc;
    }

    /**
     * @dev Allows owner to set the liquidation penalty in percentage.
     */
    function setLiquidationPenaltyPerc(uint256 _liquidationPenaltyPerc) public onlyOwner {
        liquidationPenaltyPerc = _liquidationPenaltyPerc;
    }

    /**
     * @dev Returns the collateral ratio in percentage.
     */
    function calculateCollateralRatio(uint256 collateralWorthInFUSD, uint256 totalDebt)
        internal
        pure
        returns (uint256)
    {
        require(totalDebt > 0, "CollateralRatioCalculator: Total debt must be greater than 0");

        return (collateralWorthInFUSD * 100) / totalDebt;
    }

    /**
     * @dev Checks if the collateral ratio is safe for a loan. If the function returns false,
     * the user should not be allowed to borrow FUSD.
     */
    function isCollateralRatioSafe(uint256 collateralWorthInFUSD, uint256 totalDebt) internal view returns (bool) {
        if (totalDebt == 0) return true;
        return calculateCollateralRatio(collateralWorthInFUSD, totalDebt) >= minCollateralRatioForLoanPerc;
    }

    function getLiquidationThreshold() public view virtual returns (uint256) {
        return 100 + liquidationPenaltyPerc;
    }
}
