const assert = require('assert');
const contracts = require('../compile');
const { deploy, getAccounts } = require('../utils/useWeb3');
const { timeInSecs } = require('../utils/helper');
const {
  useMethodsOn,
  useMethodOn,
  compiledContractMap,
} = require('../utils/contracts');

const getContract = compiledContractMap(contracts);

const erc20TokenName = 'USD Coin';
const erc20TokenSymbol = 'USDC';
const usdValDecimals = 8;
const erc20TokenDecimals = 18;

describe('DIAOracleV2TokenAdapter tests', () => {
  let accounts, ERC20Token, DIAOracleV2, DIAOracleV2TokenAdapter;

  beforeEach(async () => {
    accounts = await getAccounts();
    DIAOracleV2 = await deploy(
      getContract('oracles/DIAOracleV2.sol'),
      [],
      accounts[0]
    );
    ERC20Token = await deploy(
      getContract('ERC20Token.sol'),
      [erc20TokenName, erc20TokenSymbol, erc20TokenDecimals],
      accounts[0]
    );

    return useMethodOn(DIAOracleV2, {
      // We set the value for the token symbol we are using in the tests
      method: 'setValue',
      args: [`${erc20TokenSymbol}/USD`, 1 * 10 ** usdValDecimals, timeInSecs()],
      account: accounts[0],
    })
      .then(() =>
        // We deploy the token adapter contract with the oracle and token addresses.
        // The oracle must have a value for the token symbol we are using in the tests
        deploy(
          getContract('DIAOracleV2TokenAdapter.sol'),
          [DIAOracleV2.options.address, ERC20Token.options.address],
          accounts[0]
        )
      )
      .then((tokenAdapter) => {
        // We assign the adapter
        DIAOracleV2TokenAdapter = tokenAdapter;
      });
  });
  describe('DIAOracleV2TokenAdapter', () => {
    const getNewOracleInstance = () =>
      deploy(getContract('oracles/DIAOracleV2.sol'), [], accounts[0]);

    const getNewTokenInstance = (symbol) =>
      deploy(
        getContract('ERC20Token.sol'),
        [erc20TokenName, symbol, erc20TokenDecimals],
        accounts[0]
      );

    it('allows owner to change oracle', async () => {
      const DIAOracleV2Copy = await getNewOracleInstance();

      return useMethodOn(DIAOracleV2Copy, {
        // The oracle we want to update to must have a value for the token symbol
        method: 'setValue',
        args: [
          `${erc20TokenSymbol}/USD`,
          2 * 10 ** usdValDecimals,
          timeInSecs(),
        ],
        account: accounts[0],
      }).then(() =>
        useMethodsOn(DIAOracleV2TokenAdapter, [
          {
            // Owner updates the oracle
            method: 'updateOracle',
            args: [DIAOracleV2Copy.options.address],
            account: accounts[0],
          },
          {
            // We check that the oracle has been updated
            // by comparing the oracle address returned by the contract
            method: 'getOracle',
            onReturn: (oracleAddress) => {
              assert.strictEqual(
                oracleAddress,
                DIAOracleV2Copy.options.address
              );
            },
            account: accounts[0],
          },
        ])
      );
    });

    it('allows owner to change token', async () => {
      // The token we update to must have the same symbol as the current one
      const ERC20TokenCopy = await getNewTokenInstance(erc20TokenSymbol);

      return useMethodsOn(DIAOracleV2TokenAdapter, [
        {
          // Owner updates the token
          method: 'updateToken',
          args: [ERC20TokenCopy.options.address],
          account: accounts[0],
        },
        {
          // We check that the token has been updated
          // by comparing the token address returned by the contract
          method: 'getToken',
          onReturn: (tokenAddress) => {
            assert.strictEqual(tokenAddress, ERC20TokenCopy.options.address);
          },
          account: accounts[0],
        },
      ]);
    });

    it("throws error on deployment if oracle doesn't include token price", async () => {
      const DIAOracleV2Copy = await getNewOracleInstance();
      let errorRaised = false;

      await deploy(
        getContract('DIAOracleV2TokenAdapter.sol'),
        [DIAOracleV2Copy.options.address, ERC20Token.options.address],
        accounts[0]
      ).catch((error) => {
        // On deployment we expect an error to be thrown if the oracle
        // doesn't have a value for the token symbol
        errorRaised = true;
        assert.ok(error);
      });

      // We check that the error was raised
      assert.ok(errorRaised);
    });

    it("throws error on token update if token symbol doesn't match", async () => {
      const ERC20TokenCopy = await getNewTokenInstance('USDT');
      let errorRaised = false;

      return useMethodOn(DIAOracleV2TokenAdapter, {
        method: 'updateToken',
        args: [ERC20TokenCopy.options.address],
        account: accounts[0],
        catch: (error) => {
          // When updating the token, we expect an error to be thrown
          // if the token symbol doesn't match the current one
          errorRaised = true;
          assert.strictEqual(error, 'Token adapter: invalid token symbol');
        },
      }).then(() => {
        // We check that the error was raised
        assert.ok(errorRaised);
      });
    });

    it("throws error on oracle update if oracle doesn't include token price", async () => {
      const DIAOracleV2Copy = await getNewOracleInstance();
      let errorRaised = false;

      return useMethodOn(DIAOracleV2TokenAdapter, {
        method: 'updateOracle',
        args: [DIAOracleV2Copy.options.address],
        account: accounts[0],
        catch: (error) => {
          // When updating the oracle, we expect an error to be thrown
          // if the oracle doesn't have a value for the token symbol
          errorRaised = true;
          assert.strictEqual(error, 'Token adapter: invalid oracle value');
        },
      }).then(() => {
        // We check that the error was raised
        assert.ok(errorRaised);
      });
    });
  });
});
