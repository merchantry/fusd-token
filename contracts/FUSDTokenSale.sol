// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FUSDTokenHandler.sol";
import "./LiquidatingUserAssetsBelowLiquidationThreshold.sol";
import "./StoringERC20WithdrawableAddress.sol";

contract FUSDTokenSale is
    FUSDTokenHandler,
    LiquidatingUserAssetsBelowLiquidationThreshold,
    StoringERC20WithdrawableAddress
{
    constructor(
        address _fusdToken,
        uint16 annualInterestRateTenthPerc,
        uint256 minCollateralRatioForLoanPerc,
        uint256 liquidationPenaltyPerc,
        address erc20WithdrawableAddress
    )
        FUSDTokenHandler(_fusdToken)
        InterestCalculator(annualInterestRateTenthPerc)
        CollateralRatioCalculator(minCollateralRatioForLoanPerc, liquidationPenaltyPerc)
        StoringERC20WithdrawableAddress(erc20WithdrawableAddress)
        Ownable(_msgSender())
    {}

    function depositTokenAndBorrowFUSD(address token, uint256 amount, uint256 loanAmount) public {
        depositToken(token, amount);
        borrowFUSD(loanAmount);
    }

    function borrowFUSD(uint256 amount) public {
        address user = _msgSender();
        _addLoan(user, amount, time());
        registerDebtor(user);

        revertIfCollateralRatioUnsafe(user);
        mintFUSD(user, amount);
    }

    function payOffDebt(uint256 amount) public {
        address user = _msgSender();
        uint256 totalDebt = getTotalDebt(user);

        require(amount <= totalDebt, "FUSDTokenSale: amount exceeds total debt");
        _addRepayment(user, amount, time());
        address withdrawable = getERC20WithdrawableAddress();
        transferFUSD(user, withdrawable, amount);
    }

    /**
     * temporary function to deposit ERC20 tokens
     * TODO: remove this function
     */
    function depositToken(address token, uint256 amount) public {
        _depositToken(_msgSender(), token, amount);
    }

    /**
     * temporary function to withdraw ERC20 tokens
     * TODO: remove this function
     */
    function withdrawToken(address token, uint256 amount) public {
        address user = _msgSender();
        _withdrawToken(user, token, amount);
        revertIfCollateralRatioUnsafe(user);
    }

    function revertIfCollateralRatioUnsafe(address user) internal view {
        require(
            isCollateralRatioSafe(getUserCollateralWorthInFUSD(user), getTotalDebt(user)),
            "FUSDTokenSale: collateral ratio is unsafe"
        );
    }

    function isDebtorBelowLiquidationThreshold(address debtor) public view override returns (bool) {
        uint256 totalDebt = getTotalDebt(debtor);
        if (totalDebt == 0) return false;

        uint256 collateralWorthInFUSD = getUserCollateralWorthInFUSD(debtor);
        return calculateCollateralRatio(collateralWorthInFUSD, totalDebt) < getLiquidationThreshold();
    }

    function liquidateUser(address user) internal override {
        address erc20WithdrawableAddress = getERC20WithdrawableAddress();
        withdrawAllUserAssetsToWithdrawable(user, erc20WithdrawableAddress);
    }
}
