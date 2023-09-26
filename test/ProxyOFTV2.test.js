const assert = require('assert');
const contracts = require('../compile');
const { deploy, getAccounts } = require('../utils/useWeb3');
const { useMethodOn, compiledContractMap } = require('../utils/contracts');

const getContract = compiledContractMap(contracts);

const testNetEndpoint = '0x83c73Da98cf733B03315aFa8758834b36a195b87';

describe('ProxyOFTV2 tests', () => {
  let accounts, FUSDToken, ProxyOFTV2;

  beforeEach(async () => {
    accounts = await getAccounts();
    FUSDToken = await deploy(getContract('FUSDToken.sol'), [], accounts[0]);
    ProxyOFTV2 = await deploy(
      getContract('layerzero/token/oft/v2/ProxyOFTV2.sol'),
      [FUSDToken.options.address, 18, testNetEndpoint],
      accounts[0]
    );
  });

  describe('ProxyOFTV2', () => {
    it('has reference to token', () =>
      useMethodOn(ProxyOFTV2, {
        method: 'token',
        onReturn: (address) => {
          assert.strictEqual(address, FUSDToken.options.address);
        },
      }));
  });
});
