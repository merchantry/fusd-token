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
    event LiquidatedUser(address indexed user, uint256 collateralWorthInFUSD, uint256 totalDebt);

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

    function depositTokenAndBorrowFUSD(
        address token,
        uint256 amount,
        uint256 loanAmount
    ) public {
        depositToken(token, amount);
        borrowFUSD(loanAmount);
    }

    /**
     * @dev Allows the user to borrow FUSD. The user must have enough collateral
     * to borrow FUSD. The collateral ratio must be safe after borrowing FUSD, otherwise
     * the transaction reverts.
     * @param amount Amount of FUSD to borrow
     */
    function borrowFUSD(uint256 amount) public {
        address user = _msgSender();
        _addLoan(user, amount, time());
        registerDebtor(user);

        revertIfCollateralRatioUnsafe(user);
        mintFUSD(user, amount);
    }

    /**
     * @dev Allows the user to repay FUSD. The user must have enough FUSD balance
     * and allowance to repay FUSD.
     * @param amount Amount of FUSD to repay
     */
    function payOffDebt(uint256 amount) public {
        address user = _msgSender();
        uint256 totalDebt = getTotalDebt(user);

        require(amount <= totalDebt, "FUSDTokenSale: amount exceeds total debt");
        _addRepayment(user, amount, time());
        address withdrawable = getERC20WithdrawableAddress();
        transferFUSD(user, withdrawable, amount);
    }

    /**
     * @dev Allows the user to repay all FUSD debt. The user must have enough FUSD balance
     * and allowance to repay FUSD.
     */
    function payOffAllDebt() public {
        payOffDebt(getTotalDebt(_msgSender()));
    }

    /**
     * @dev Allows the user to deposit tokens as collateral. The user must have enough
     * token balance and allowance to deposit tokens. The token must have a valid
     * adapter, otherwise the transaction reverts.
     * @param token Address of the token to deposit
     * @param amount Amount of the token to deposit
     */
    function depositToken(address token, uint256 amount) public {
        _depositToken(_msgSender(), token, amount);
    }

    /**
     * @dev Allows the user to withdraw tokens. The user must have sufficient collateral
     * ratio after the transaction for the withdrawal to go through.
     * The token must have a valid adapter, otherwise the transaction reverts.
     * @param token Address of the token to withdraw
     * @param amount Amount of the token to withdraw
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

    /**
     * @dev Returns the collateral ratio for a user in percentage. The collateral ratio
     * is calculated using the total worth of the user's collateral in FUSD and the
     * total debt in FUSD. Then the collateral worth is divided by the total debt
     */
    function getCollateralRatio(address user) public view returns (uint256) {
        return calculateCollateralRatio(getUserCollateralWorthInFUSD(user), getTotalDebt(user));
    }

    /**
     * @dev Returns true if the user's collateral ratio is below the liquidation threshold.
     * Users flagged by this function will be liquidated when owner calls `liquidateAllDebtorsBelowLiquidationThreshold()`.
     */
    function isDebtorBelowLiquidationThreshold(address debtor) public view override returns (bool) {
        uint256 totalDebt = getTotalDebt(debtor);
        if (totalDebt == 0) return false;

        uint256 collateralWorthInFUSD = getUserCollateralWorthInFUSD(debtor);
        return calculateCollateralRatio(collateralWorthInFUSD, totalDebt) < getLiquidationThreshold();
    }

    /**
     * Liquidates user. Sends all user collateral assets to the ERC20WithdrawableAddress
     * and erases the user's debt. A liquidation event is emitted.
     */
    function liquidateUser(address user) internal override {
        address erc20WithdrawableAddress = getERC20WithdrawableAddress();
        uint256 totalDebt = getTotalDebt(user);

        emit LiquidatedUser(user, getUserCollateralWorthInFUSD(user), totalDebt);

        withdrawAllUserAssetsToWithdrawable(user, erc20WithdrawableAddress);
        _addRepayment(user, totalDebt, time());
    }
}
