const assert = require('assert');
const contracts = require('../compile');
const { deploy, getAccounts } = require('../utils/useWeb3');
const { timeInSecs, runPromisesInSequence } = require('../utils/helper');
const {
  useMethodsOn,
  useMethodOn,
  compiledContractMap,
} = require('../utils/contracts');

const getContract = compiledContractMap(contracts);

const erc20TokenName = 'TELOS';
const erc20TokenSymbol = 'WTLOS';
const oracleTokenKey = 'TLOS/USD';
const usdValDecimals = 8;
const erc20TokenDecimals = 18;

describe('DIAOracleV2wTLOSAdapter tests', () => {
  let accounts, ERC20Token, DIAOracleV2, DIAOracleV2wTLOSAdapter;

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
      args: [oracleTokenKey, 1 * 10 ** usdValDecimals, timeInSecs()],
      account: accounts[0],
    })
      .then(() =>
        // We deploy the token adapter contract with the oracle and token addresses.
        // The oracle must have a value for the token symbol we are using in the tests
        deploy(
          getContract('DIAOracleV2wTLOSAdapter.sol'),
          [DIAOracleV2.options.address, ERC20Token.options.address],
          accounts[0]
        )
      )
      .then((tokenAdapter) => {
        // We assign the adapter
        DIAOracleV2wTLOSAdapter = tokenAdapter;
      });
  });
  describe('DIAOracleV2wTLOSAdapter', () => {
    const getNewOracleInstance = () =>
      deploy(getContract('oracles/DIAOracleV2.sol'), [], accounts[0]);

    const getNewTokenInstance = (symbol) =>
      deploy(
        getContract('ERC20Token.sol'),
        [erc20TokenName, symbol, erc20TokenDecimals],
        accounts[0]
      );

    it('allows owner to change wTLOS reference', async () => {
      // The token we update to must have TLOS symbol
      const ERC20TokenCopy = await getNewTokenInstance(erc20TokenSymbol);

      return useMethodsOn(DIAOracleV2wTLOSAdapter, [
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
        getContract('DIAOracleV2wTLOSAdapter.sol'),
        [DIAOracleV2Copy.options.address, ERC20Token.options.address],
        accounts[0]
      ).catch((error) => {
        // On deployment we expect an error to be thrown if the oracle
        // doesn't have a value for TLOS/USD
        errorRaised = true;
        assert.ok(error);
      });

      // We check that the error was raised
      assert.ok(errorRaised);
    });

    it("throws error on token update if token symbol doesn't match", () => {
      const testCases = [
        {
          symbol: 'TLOS',
          expectError: true,
        },
        {
          // WTLOS is the only valid symbol for the token
          symbol: 'WTLOS',
          expectError: false,
        },
        {
          symbol: 'TLO',
          expectError: true,
        },
      ];

      return runPromisesInSequence(
        testCases.map(({ symbol, expectError }) => async () => {
          const ERC20TokenCopy = await getNewTokenInstance(symbol);
          let errorRaised = false;

          return useMethodOn(DIAOracleV2wTLOSAdapter, {
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
            assert.ok(errorRaised === expectError, `Symbol: ${symbol}`);
          });
        })
      );
    });

    it("throws error on oracle update if oracle doesn't TLOS/USD value", () => {
      const testCases = [
        {
          // TLOS/USD is the only valid oracle key
          symbol: 'TLOS',
          expectError: false,
        },
        {
          symbol: 'wTLOS',
          expectError: true,
        },
        {
          symbol: 'TLO',
          expectError: true,
        },
      ];

      return runPromisesInSequence(
        testCases.map(({ symbol, expectError }) => async () => {
          const DIAOracleV2Copy = await getNewOracleInstance();
          let errorRaised = false;

          return useMethodOn(DIAOracleV2Copy, {
            // We set the value for the token symbol we are using in the tests
            method: 'setValue',
            args: [`${symbol}/USD`, 1 * 10 ** usdValDecimals, timeInSecs()],
            account: accounts[0],
          })
            .then(() =>
              useMethodOn(DIAOracleV2wTLOSAdapter, {
                method: 'updateOracle',
                args: [DIAOracleV2Copy.options.address],
                account: accounts[0],
                catch: (error) => {
                  // When updating the oracle, we expect an error to be thrown
                  // if the oracle doesn't have a value for the token symbol
                  errorRaised = true;
                  assert.strictEqual(
                    error,
                    'Token adapter: invalid oracle value'
                  );
                },
              })
            )
            .then(() => {
              // We check that the error was raised
              assert.ok(errorRaised === expectError, `Symbol: ${symbol}`);
            });
        })
      );
    });
  });
});
