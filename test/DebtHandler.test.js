const assert = require('assert');
const contracts = require('../compile');
const { deploy, getAccounts } = require('../utils/useWeb3');
const { useMethodsOn, timeInSecs, useMethodOn } = require('../utils/helper');

const debtHandlerContract =
  contracts['test/DebtHandlerTestContract.sol'].DebtHandlerTestContract;

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

    const setUpDebtChanges = () => {
      const time = timeInSecs();

      return useMethodsOn(
        DebtHandler,
        userDebtChanges.map((debtChange) => ({
          method: debtChange.amount < 0 ? 'addRepayment' : 'addLoan',
          args: [
            accounts[0],
            Math.abs(debtChange.amount),
            time - year + debtChange.timestamp,
          ],
          account: accounts[0],
        }))
      );
    };

    it('records debt changes', () =>
      setUpDebtChanges().then(() =>
        useMethodOn(DebtHandler, {
          method: 'getDebtChanges',
          args: [accounts[0]],
          onReturn: (result) => {
            assert.strictEqual(result.length, userDebtChanges.length);
            result.forEach((debtChange, i) => {
              const { amount } = userDebtChanges[i];
              const action =
                amount < 0 ? debtAction.ADD_REPAYMENT : debtAction.ADD_LOAN;

              assert.strictEqual(parseInt(debtChange.amount), Math.abs(amount));
              assert.strictEqual(parseInt(debtChange.action), action);
            });
          },
        })
      ));

    it('calculates total debt and interest', () =>
      setUpDebtChanges().then(() =>
        useMethodOn(DebtHandler, {
          method: 'calculateTotalLoanAndInterest',
          args: [accounts[0]],
          onReturn: (result) => {
            console.log(result);
          },
        })
      ));
  });
});
