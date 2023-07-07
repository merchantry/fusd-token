// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin/access/Ownable.sol";

abstract contract InterestCalculator is Ownable {
    // Each point of annualInterestRateTenthPercent represents 0.1% of annual interest rate.
    uint16 private annualInterestRateTenthPerc;
    uint16 private constant MAX_INTEREST_RATE = 1000;

    constructor(uint16 _annualInterestRateTenthPerc) validAnnualInterestRate(_annualInterestRateTenthPerc) {
        annualInterestRateTenthPerc = _annualInterestRateTenthPerc;
    }

    modifier validAnnualInterestRate(uint16 _annualInterestRateTenthPerc) {
        require(
            0 <= _annualInterestRateTenthPerc && _annualInterestRateTenthPerc <= MAX_INTEREST_RATE,
            "InterestCalculator: Invalid annual interest rate"
        );
        _;
    }

    function getAnnualInterestRateTenthPerc() public view returns (uint16) {
        return annualInterestRateTenthPerc;
    }

    /**
     * @dev Allows the owner to set the annual interest rate.
     * Each point of annualInterestRateTenthPercent represents 0.1% of annual interest rate.
     * @param _annualInterestRateTenthPerc Annual interest rate in tenth percent. Must be between 0 and 1000 (0% and 100.0%).
     */
    function setAnnualInterestRateTenthPerc(uint16 _annualInterestRateTenthPerc)
        public
        onlyOwner
        validAnnualInterestRate(_annualInterestRateTenthPerc)
    {
        annualInterestRateTenthPerc = _annualInterestRateTenthPerc;
    }

    function calculateInterest(
        uint256 amount,
        uint256 loanedAt,
        uint256 currentTimestamp
    ) internal view returns (uint256) {
        uint256 timeDiff = currentTimestamp - loanedAt;
        return (amount * timeDiff * annualInterestRateTenthPerc) / (1000 * 365 days);
    }
}
