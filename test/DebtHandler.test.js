const assert = require('assert');
const contracts = require('../compile');
const { deploy, getAccounts } = require('../utils/useWeb3');
const { useMethodsOn, timeInSecs, useMethodOn } = require('../utils/helper');

const debtHandlerContract =
  contracts['test/DebtHandlerTestContract.sol'].DebtHandlerTestContract;

// 1 tenth of a percent = 0.1%
const annualInterestRateTenthPerc = 60;
const minute = 60;
const hour = 60 * minute;
const day = 24 * hour;
const month = 30 * day;
const year = 365 * day;

const debtAction = {
  ADD_LOAN: 0,
  ADD_REPAYMENT: 1,
};

const userDebtChanges = [
  {
    amount: 100,
    timestamp: 0,
  },
  {
    amount: 200,
    timestamp: 1 * month,
  },
  {
    amount: 300,
    timestamp: 2 * month,
  },
  {
    amount: -200,
    timestamp: 3 * month,
  },
];

describe('DebtHandler tests', () => {
  let accounts, DebtHandler;

  beforeEach(async () => {
    accounts = await getAccounts();
    DebtHandler = await deploy(
      debtHandlerContract,
      [annualInterestRateTenthPerc],
      accounts[0]
    );
  });

  describe('DebtHandler', () => {
    it('deploys successfully', () => {
      assert.ok(DebtHandler.options.address);
    });

    /**
     * Sets up debt changes for a user. If the change amount is negative,
     * it is considered a repayment, otherwise it is considered a loan.
     */
    const setUpDebtChanges = () => {
      const time = timeInSecs();

      return useMethodsOn(
        DebtHandler,
        userDebtChanges.map((debtChange) => ({
          method: debtChange.amount < 0 ? 'addRepayment' : 'addLoan',
          args: [
            accounts[0],
            Math.abs(debtChange.amount),
            // In these tests we use the timestamp of the debt change
            // as the timestamp of the transaction. In reality, the timestamp
            // should be automatically set to the current time in the contract.
            // debtChange.timestamp represents the time in seconds since one year ago.
            time - year + debtChange.timestamp,
          ],
          account: accounts[0],
        }))
      );
    };

    it('records debt changes', () =>
      setUpDebtChanges().then(() =>
        useMethodOn(DebtHandler, {
          // We get a list of all debt changes from the contract
          method: 'getDebtChanges',
          args: [accounts[0]],
          onReturn: (result) => {
            assert.strictEqual(result.length, userDebtChanges.length);
            result.forEach((debtChange, i) => {
              const { amount } = userDebtChanges[i];
              const action =
                amount < 0 ? debtAction.ADD_REPAYMENT : debtAction.ADD_LOAN;

              // We check that the debt changes are recorded correctly
              assert.strictEqual(parseInt(debtChange.amount), Math.abs(amount));
              assert.strictEqual(parseInt(debtChange.action), action);
            });
          },
        })
      ));

    it('calculates base debt and interest', () =>
      setUpDebtChanges().then(() =>
        useMethodOn(DebtHandler, {
          method: 'calculateBaseDebtAndInterest',
          args: [accounts[0]],
          onReturn: (result) => {
            const [baseDebt, totalInterest] = Object.values(result).map(
              (value) => parseInt(value)
            );

            const totalDebtChanges = userDebtChanges.reduce(
              (total, { amount }) => total + amount,
              0
            );

            // baseDebt should be greater than totalDebtChanges,
            // since interest is added to the total debt
            // and when repaying, first the interest is paid
            // and then the base debt
            assert.ok(baseDebt > totalDebtChanges);
            assert.ok(totalInterest > 0);
          },
        })
      ));

    it('calculates total debt', () =>
      setUpDebtChanges().then(() =>
        useMethodOn(DebtHandler, {
          method: 'getTotalDebt',
          args: [accounts[0]],
          onReturn: (result) => {
            const totalDebt = parseInt(result);
            const totalDebtChanges = userDebtChanges.reduce(
              (total, { amount }) => total + amount,
              0
            );

            // totalDebt should be greater than totalDebtChanges,
            // since interest is added to the total debt
            assert.ok(totalDebt > totalDebtChanges);
          },
        })
      ));
  });

  describe('InterestCalculator', () => {
    it('throws error if deployed with invalid annual interest rate', async () => {
      let errorRaised = false;

      await deploy(debtHandlerContract, [1001], accounts[0]).catch((error) => {
        // On deployment we expect an error to be thrown
        // if the annual interest rate is invalid
        errorRaised = true;
        assert.ok(error);
      });

      // We check that the error was raised
      assert.ok(errorRaised);
    });

    it('throws error on annual interest rate update if value is invalid', () => {
      let errorRaised = false;

      return useMethodOn(DebtHandler, {
        method: 'setAnnualInterestRateTenthPerc',
        args: [1001],
        account: accounts[0],
        catch: (error) => {
          // On update we expect an error to be thrown
          // if the annual interest rate is invalid
          errorRaised = true;
          assert.strictEqual(
            error,
            'InterestCalculator: Invalid annual interest rate'
          );
        },
      }).then(() => {
        // We check that the error was raised
        assert.ok(errorRaised);
      });
    });
  });
});
