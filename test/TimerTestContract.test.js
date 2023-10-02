const assert = require('assert');
const contracts = require('../compile');
const { deploy, getAccounts } = require('../utils/useWeb3');
const { schedule, everySecond } = require('../utils/cronJob');
const { useMethodOn, compiledContractMap } = require('../utils/contracts');
const { timeInSecs } = require('../utils/helper');

const getContract = compiledContractMap(contracts);

const secondsToWait = 3;

describe('Cron job tests', () => {
  let accounts, deployedAt, TimerTestContract;

  beforeEach(async () => {
    accounts = await getAccounts();
    deployedAt = timeInSecs();
    TimerTestContract = await deploy(
      getContract('test/TimerTestContract.sol'),
      [deployedAt, secondsToWait],
      accounts[0]
    );
  });

  describe('TimerTestContract', () => {
    it('deploys successfully', () => {
      assert.ok(TimerTestContract.options.address);
    });
  });

  describe('Node.js cron job', () => {
    it('calls isReady method', () =>
      new Promise((resolve) => {
        const job = schedule(everySecond, async () => {
          const time = timeInSecs();
          const value = await useMethodOn(TimerTestContract, {
            method: 'isReady',
            args: [time],
            onReturn: () => {},
          });

          assert.strictEqual(value, time >= deployedAt + secondsToWait);
        });

        setTimeout(() => {
          job.stop();
          resolve();
        }, (secondsToWait + 1) * 1000);
      }));

    it('calls setAction method if isReady returns true', () =>
      new Promise((resolve) => {
        const job = schedule(everySecond, async () => {
          const time = timeInSecs();
          const value = await useMethodOn(TimerTestContract, {
            method: 'isReady',
            args: [time],
            onReturn: () => {},
          });

          if (!value) return;
          await useMethodOn(TimerTestContract, {
            method: 'setActionCompleted',
            account: accounts[0],
          });
        });

        setTimeout(async () => {
          const actionCompleted = await useMethodOn(TimerTestContract, {
            method: 'getActionCompleted',
            account: accounts[0],
          });

          assert.ok(actionCompleted);
          job.stop();
          resolve();
        }, (secondsToWait + 1) * 1000);
      }));
  });
});
