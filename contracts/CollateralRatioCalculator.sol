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

    function getMinCollateralRatioForLoanPerc() public view returns (uint256) {
        return minCollateralRatioForLoanPerc;
    }

    function setMinCollateralRatioForLoanPerc(uint256 _minCollateralRatioForLoanPerc) public onlyOwner {
        minCollateralRatioForLoanPerc = _minCollateralRatioForLoanPerc;
    }

    function getLiquidationPenaltyPerc() public view returns (uint256) {
        return liquidationPenaltyPerc;
    }

    function setLiquidationPenaltyPerc(uint256 _liquidationPenaltyPerc) public onlyOwner {
        liquidationPenaltyPerc = _liquidationPenaltyPerc;
    }

    function calculateCollateralRatio(
        uint256 collateralWorthInFUSD,
        uint256 totalDebt
    ) internal pure returns (uint256) {
        require(totalDebt > 0, "CollateralRatioCalculator: Total debt must be greater than 0");

        return (collateralWorthInFUSD * 100) / totalDebt;
    }

    function isCollateralRatioSafe(uint256 collateralWorthInFUSD, uint256 totalDebt) internal view returns (bool) {
        if (totalDebt == 0) return true;
        return calculateCollateralRatio(collateralWorthInFUSD, totalDebt) >= minCollateralRatioForLoanPerc;
    }

    function getLiquidationThreshold() public view virtual returns (uint256) {
        return 100 + liquidationPenaltyPerc;
    }
}
