// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin/access/Ownable.sol";

abstract contract InterestCalculator is Ownable {
    // Each point of annualInterestRateTenthPercent represents 0.1% of annual interest rate.
    uint16 private annualInterestRateTenthPerc;

    constructor(uint16 _annualInterestRateTenthPerc) {
        annualInterestRateTenthPerc = _annualInterestRateTenthPerc;
    }

    function getAnnualInterestRateTenthPerc() public view returns (uint16) {
        return annualInterestRateTenthPerc;
    }

    function setAnnualInterestRateTenthPerc(uint16 _annualInterestRateTenthPerc) public onlyOwner {
        annualInterestRateTenthPerc = _annualInterestRateTenthPerc;
    }

    function calculateInterest(
        uint256 amount,
        uint256 loanedAt,
        uint256 currentTimestamp
    ) internal view returns (uint256) {
        uint256 timeDiff = currentTimestamp - loanedAt;
        return (amount * timeDiff * annualInterestRateTenthPerc) / (1000 * 365 * 24 * 60 * 60);
    }
}
