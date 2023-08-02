// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FUSDTokenSaleUtils/FUSDTokenHandler.sol";
import "./FUSDTokenSaleUtils/LiquidatingUserAssetsBelowLiquidationThreshold.sol";
import "./FUSDTokenSaleUtils/StoringERC20WithdrawableAddress.sol";

contract FUSDTokenSale is
    FUSDTokenHandler,
    LiquidatingUserAssetsBelowLiquidationThreshold,
    StoringERC20WithdrawableAddress
{
    event LiquidatedUser(address indexed user, uint256 collateralWorthInFUSD, uint256 totalDebt);

    constructor(
        address _fusdToken,
        uint16 annualInterestRateTenthPerc,
        uint256 minCollateralRatioForLoanTenthPerc,
        uint256 liquidationPenaltyTenthPerc,
        address erc20WithdrawableAddress
    )
        FUSDTokenHandler(_fusdToken)
        InterestCalculator(annualInterestRateTenthPerc)
        CollateralRatioCalculator(minCollateralRatioForLoanTenthPerc, liquidationPenaltyTenthPerc)
        StoringERC20WithdrawableAddress(erc20WithdrawableAddress)
        Ownable(_msgSender())
        LTIsBelowMinCR(annualInterestRateTenthPerc, liquidationPenaltyTenthPerc, minCollateralRatioForLoanTenthPerc)
    {}

    modifier LTIsBelowMinCR(
        uint256 annualInterestRateTenthPerc,
        uint256 liquidationPenaltyTenthPerc,
        uint256 minCollateralRatioForLoanTenthPerc
    ) {
        require(
            1000 + liquidationPenaltyTenthPerc + annualInterestRateTenthPerc < minCollateralRatioForLoanTenthPerc,
            "FUSDTokenSale: Liquidation threshold must be below minimum collateral ratio"
        );
        _;
    }

    modifier collateralRatioSafe(address user) {
        _;
        require(
            isCollateralRatioSafe(getUserCollateralWorthInFUSD(user), getTotalDebt(user)),
            "FUSDTokenSale: collateral ratio is unsafe"
        );
    }

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
    function borrowFUSD(uint256 amount) public collateralRatioSafe(_msgSender()) {
        address user = _msgSender();

        _addLoan(user, amount, time());
        registerDebtor(user);
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
    function withdrawToken(address token, uint256 amount) public collateralRatioSafe(_msgSender()) {
        _withdrawToken(_msgSender(), token, amount);
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

    /**
     * @dev Allows owner to set the minimum collateral ratio required for a loan in 0.1%.
     * The minimum collateral ratio must be below the liquidation threshold.
     */
    function setMinCollateralRatioForLoanTenthPerc(uint256 _minCollateralRatioForLoanTenthPerc)
        public
        override
        onlyOwner
        LTIsBelowMinCR(
            getAnnualInterestRateTenthPerc(),
            getLiquidationPenaltyTenthPerc(),
            _minCollateralRatioForLoanTenthPerc
        )
    {
        super.setMinCollateralRatioForLoanTenthPerc(_minCollateralRatioForLoanTenthPerc);
    }

    /**
     * @dev Allows owner to set the liquidation penalty in 0.1%.
     * The resulting liquidation penalty must be below the minimum collateral ratio.
     */
    function setLiquidationPenaltyTenthPerc(uint256 _liquidationPenaltyTenthPerc)
        public
        override
        onlyOwner
        LTIsBelowMinCR(
            getAnnualInterestRateTenthPerc(),
            _liquidationPenaltyTenthPerc,
            getMinCollateralRatioForLoanTenthPerc()
        )
    {
        super.setLiquidationPenaltyTenthPerc(_liquidationPenaltyTenthPerc);
    }

    /**
     * @dev Allows the owner to set the annual interest rate.
     * Each point of annualInterestRateTenthPercent represents 0.1% of annual interest rate.
     * The resulting liquidation penalty must be below the minimum collateral ratio.
     * @param _annualInterestRateTenthPerc Annual interest rate in tenth percent. Must be between 0 and 1000 (0% and 100.0%).
     */
    function setAnnualInterestRateTenthPerc(uint16 _annualInterestRateTenthPerc)
        public
        override
        onlyOwner
        LTIsBelowMinCR(
            _annualInterestRateTenthPerc,
            getLiquidationPenaltyTenthPerc(),
            getMinCollateralRatioForLoanTenthPerc()
        )
    {
        super.setAnnualInterestRateTenthPerc(_annualInterestRateTenthPerc);
    }

    /**
     * @dev Returns the maximum amount of FUSD the user can borrow. If the user falls
     * below the minimum collateral ratio, returns 0.
     * @param user Address of the user
     */
    function calculateMaxFUSDToBorrow(address user) public view returns (uint256) {
        uint256 collateralWorthInFUSD = getUserCollateralWorthInFUSD(user);
        uint256 totalDebt = getTotalDebt(user);
        uint256 minCollateralRatio = getMinCollateralRatioForLoanTenthPerc();

        uint256 totalAllowedToBorrow = (collateralWorthInFUSD * 1000) / minCollateralRatio;

        if (totalAllowedToBorrow <= totalDebt) return 0;

        return totalAllowedToBorrow - totalDebt;
    }

    /**
     * @dev Returns the maximum amount of collateral the user can withdraw. If the user falls
     * below the minimum collateral ratio, returns 0.
     * @param user Address of the user
     */
    function calculateMaxCollateralToWithdraw(address user) public view returns (uint256) {
        uint256 collateralWorthInFUSD = getUserCollateralWorthInFUSD(user);
        uint256 totalDebt = getTotalDebt(user);
        uint256 minCollateralRatio = getMinCollateralRatioForLoanTenthPerc();

        uint256 totalAllowedToWithdraw = (totalDebt * minCollateralRatio) / 1000;

        if (totalAllowedToWithdraw >= collateralWorthInFUSD) return 0;

        return collateralWorthInFUSD - totalAllowedToWithdraw;
    }
}
