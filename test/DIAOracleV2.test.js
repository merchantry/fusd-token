const assert = require('assert');
const contracts = require('../compile');
const { deploy, getAccounts } = require('../utils/useWeb3');
const { useMethodsOn } = require('../utils/helper');

const oracleContract = contracts['oracles/DIAOracleV2.sol'].DIAOracleV2;

const key = 'TLOS/USD';
const value = 150;

describe('DIAOracleV2 tests', () => {
  let accounts, DIAOracleV2;

  beforeEach(async () => {
    accounts = await getAccounts();
    DIAOracleV2 = await deploy(oracleContract, [], accounts[0]);
  });

  describe('DIAOracleV2', () => {
    it('deploys successfully', () => {
      assert.ok(DIAOracleV2.options.address);
    });

    it('allows the owner to update the oracle value', async () => {
      const currentTime = Math.floor(Date.now() / 1000);

      return useMethodsOn(DIAOracleV2, [
        {
          method: 'setValue',
          args: [key, value, currentTime],
          account: accounts[0],
        },
        {
          method: 'getValue',
          args: [key],
          onReturn: (result) => {
            assert.strictEqual(parseInt(result[0]), value);
          },
          account: accounts[0],
        },
      ]);
    });
  });
});
