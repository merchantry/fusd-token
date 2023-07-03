const assert = require('assert');
const contracts = require('../compile');
const { deploy, getAccounts } = require('../utils/useWeb3');

const tokenContract = contracts['FUSDToken.sol'].FUSDToken;

describe('FUSDToken tests', () => {
  let accounts, FUSDToken;

  beforeEach(async () => {
    accounts = await getAccounts();
    FUSDToken = await deploy(tokenContract, [], accounts[0]);
  });

  describe('FUSDToken', () => {
    it('deploys successfully', () => {
      assert.ok(FUSDToken.options.address);
    });
  });
});
