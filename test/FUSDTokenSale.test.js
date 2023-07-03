const assert = require('assert');
const contracts = require('../compile');
const {
  deploy,
  getAccounts,
  getDeployedContract,
} = require('../utils/useWeb3');
const {
  useMethodsOn,
  timeInSecs,
  randomInt,
  newArray,
  runPromisesInSequence,
  useMethodOn,
} = require('../utils/helper');

const erc20TokenContract = contracts['test/ERC20Token.sol'].ERC20Token;
const fusdTokenContract = contracts['FUSDToken.sol'].FUSDToken;
const tokenSaleContract = contracts['FUSDTokenSale.sol'].FUSDTokenSale;
const adapterContract =
  contracts['DIAOracleV2TokenAdapter.sol'].DIAOracleV2TokenAdapter;
const oracleContract = contracts['oracles/DIAOracleV2.sol'].DIAOracleV2;

const erc20TokenName = 'USD Coin';
const erc20TokenSymbol = 'USDC';
const fusdDecimals = 18;
const usdValDecimals = 8;
const erc20TokenDecimals = 18;

const symbols = ['USDT', 'USDC', 'DAI'];

describe('FUSDTokenSale tests', () => {
  let accounts,
    FUSDToken,
    FUSDTokenSale,
    ERC20Token,
    DIAOracleV2,
    DIAOracleV2TokenAdapter;

  beforeEach(async () => {
    accounts = await getAccounts();
    FUSDToken = await deploy(fusdTokenContract, [], accounts[0]);
    FUSDTokenSale = await deploy(
      tokenSaleContract,
      [FUSDToken.options.address],
      accounts[0]
    );
    DIAOracleV2 = await deploy(oracleContract, [], accounts[0]);
    ERC20Token = await deploy(
      erc20TokenContract,
      [erc20TokenName, erc20TokenSymbol, erc20TokenDecimals],
      accounts[0]
    );
  });

  const setUpOracle = () =>
    useMethodOn(DIAOracleV2, {
      method: 'setValue',
      args: [`${erc20TokenSymbol}/USD`, 1 * 10 ** usdValDecimals, timeInSecs()],
      account: accounts[0],
    })
      .then(() =>
        deploy(
          adapterContract,
          [DIAOracleV2.options.address, ERC20Token.options.address],
          accounts[0]
        )
      )
      .then((tokenAdapter) => {
        DIAOracleV2TokenAdapter = tokenAdapter;
      });

  const generateERC20Params = () =>
    symbols.reduce((params, symbol) => {
      params[symbol] = {
        decimals: randomInt(8, 12),
        usdOracleValue: randomInt(1, 100) * 10 ** usdValDecimals,
      };
      return params;
    }, {});

  const setUpMultipleTokenAdapters = async (params = generateERC20Params()) => {
    const ERC20Tokens = await Promise.all(
      Object.entries(params).map(([symbol, { decimals }]) =>
        deploy(
          erc20TokenContract,
          [erc20TokenName, symbol, decimals],
          accounts[0]
        )
      )
    );

    return useMethodsOn(
      DIAOracleV2,
      symbols.map((symbol) => ({
        method: 'setValue',
        args: [`${symbol}/USD`, params[symbol].usdOracleValue, timeInSecs()],
        account: accounts[0],
      }))
    )
      .then(() =>
        Promise.all(
          ERC20Tokens.map((token) =>
            deploy(
              adapterContract,
              [DIAOracleV2.options.address, token.options.address],
              accounts[0]
            )
          )
        )
      )
      .then((tokenAdapters) =>
        useMethodsOn(FUSDTokenSale, [
          ...tokenAdapters.map((tokenAdapter) => ({
            method: 'addTokenAdapter',
            args: [tokenAdapter.options.address],
            account: accounts[0],
          })),
        ])
      );
  };

  const getTokenContractAndSymbolFromAdapter = async (adapterAddress) => {
    const TokenAdapter = await getDeployedContract(
      adapterContract,
      adapterAddress
    );

    const tokenAddress = await useMethodOn(TokenAdapter, {
      method: 'getToken',
      onReturn: () => {},
    });

    const Token = await getDeployedContract(erc20TokenContract, tokenAddress);
    const tokenSymbol = await useMethodOn(Token, {
      method: 'symbol',
      onReturn: () => {},
    });

    return { Token, tokenSymbol };
  };

  describe('FUSDTokenSale', () => {
    it('deploys successfully', () => {
      assert.ok(FUSDTokenSale.options.address);
    });

    it('calculates adapted token price in FUSD correctly', () => {
      const tokenContracts = {};
      const erc20Params = generateERC20Params();

      return setUpMultipleTokenAdapters(erc20Params)
        .then(() =>
          useMethodOn(FUSDTokenSale, {
            method: 'getTokenAdapterAddresses',
            onReturn: () => {},
          })
        )
        .then((tokenAdapterAddresses) =>
          runPromisesInSequence(
            tokenAdapterAddresses.map(() => async (_, i) => {
              const { Token, tokenSymbol } =
                await getTokenContractAndSymbolFromAdapter(
                  tokenAdapterAddresses[i]
                );
              tokenContracts[tokenSymbol] = Token;
            })
          )
        )
        .then(() =>
          useMethodsOn(
            FUSDTokenSale,
            Object.entries(tokenContracts).map(([symbol, token]) => ({
              method: 'tokenPriceInFUSD',
              args: [token.options.address, 1],
              onReturn: (price) => {
                const { decimals, usdOracleValue } = erc20Params[symbol];
                const expectedPrice =
                  usdOracleValue *
                  10 ** (fusdDecimals - decimals - usdValDecimals);
                assert.strictEqual(parseInt(price), expectedPrice);
              },
            }))
          )
        );
    });
  });

  describe('DIAOracleV2TokenAdapter', () => {
    const getNewOracleInstance = () => deploy(oracleContract, [], accounts[0]);

    const getNewTokenInstance = (symbol) =>
      deploy(
        erc20TokenContract,
        [erc20TokenName, symbol, erc20TokenDecimals],
        accounts[0]
      );

    it('allows owner to change oracle', async () => {
      const DIAOracleV2Copy = await getNewOracleInstance();
      const currentTime = timeInSecs();

      return setUpOracle()
        .then(() =>
          useMethodOn(DIAOracleV2Copy, {
            method: 'setValue',
            args: [
              `${erc20TokenSymbol}/USD`,
              2 * 10 ** usdValDecimals,
              currentTime,
            ],
            account: accounts[0],
          })
        )
        .then(() =>
          useMethodsOn(DIAOracleV2TokenAdapter, [
            {
              method: 'updateOracle',
              args: [DIAOracleV2Copy.options.address],
              account: accounts[0],
            },
            {
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
      const ERC20TokenCopy = await getNewTokenInstance(erc20TokenSymbol);

      return setUpOracle().then(() =>
        useMethodsOn(DIAOracleV2TokenAdapter, [
          {
            method: 'updateToken',
            args: [ERC20TokenCopy.options.address],
            account: accounts[0],
          },
          {
            method: 'getToken',
            onReturn: (tokenAddress) => {
              assert.strictEqual(tokenAddress, ERC20TokenCopy.options.address);
            },
            account: accounts[0],
          },
        ])
      );
    });

    it("throws error on deployment if oracle doesn't include token price", async () => {
      let errorRaised = false;

      await deploy(
        adapterContract,
        [DIAOracleV2.options.address, ERC20Token.options.address],
        accounts[0]
      ).catch((error) => {
        errorRaised = true;
        assert.ok(error);
      });

      assert.ok(errorRaised);
    });

    it("throws error on token update if token symbol doesn't match", async () => {
      const ERC20TokenCopy = await getNewTokenInstance('USDT');
      let errorRaised = false;

      return setUpOracle()
        .then(() =>
          useMethodOn(DIAOracleV2TokenAdapter, {
            method: 'updateToken',
            args: [ERC20TokenCopy.options.address],
            account: accounts[0],
            catch: (error) => {
              errorRaised = true;
              assert.strictEqual(error, 'Token adapter: invalid token symbol');
            },
          })
        )
        .then(() => {
          assert.ok(errorRaised);
        });
    });

    it("throws error on oracle update if oracle doesn't include token price", async () => {
      const DIAOracleV2Copy = await getNewOracleInstance();
      let errorRaised = false;

      return setUpOracle()
        .then(() =>
          useMethodOn(DIAOracleV2TokenAdapter, {
            method: 'updateOracle',
            args: [DIAOracleV2Copy.options.address],
            account: accounts[0],
            catch: (error) => {
              errorRaised = true;
              assert.strictEqual(error, 'Token adapter: invalid oracle value');
            },
          })
        )
        .then(() => {
          assert.ok(errorRaised);
        });
    });
  });

  describe('TokenAdapterFactory', () => {
    it('allows to add a token adapter reference', () =>
      setUpOracle().then(() =>
        useMethodsOn(FUSDTokenSale, [
          {
            method: 'addTokenAdapter',
            args: [DIAOracleV2TokenAdapter.options.address],
            account: accounts[0],
          },
          {
            method: 'getTokenAdapterAddresses',
            onReturn: ([tokenAdapterAddress]) => {
              assert.strictEqual(
                tokenAdapterAddress,
                DIAOracleV2TokenAdapter.options.address
              );
            },
          },
        ])
      ));

    it('returns all token symbols', async () =>
      setUpMultipleTokenAdapters().then(() =>
        useMethodOn(FUSDTokenSale, {
          method: 'getTokenSymbols',
          onReturn: (result) => {
            assert.deepStrictEqual(result, symbols);
          },
        })
      ));

    it('throws error if token adapter already exists', async () => {
      let errorRaised = false;

      return setUpOracle()
        .then(() =>
          useMethodsOn(FUSDTokenSale, [
            {
              method: 'addTokenAdapter',
              args: [DIAOracleV2TokenAdapter.options.address],
              account: accounts[0],
            },
            {
              method: 'addTokenAdapter',
              args: [DIAOracleV2TokenAdapter.options.address],
              account: accounts[0],
              catch: (error) => {
                errorRaised = true;
                assert.strictEqual(error, 'Token adapter already exists');
              },
            },
          ])
        )
        .then(() => {
          assert.ok(errorRaised);
        });
    });
  });

  describe('ERC20ExchangeVault', () => {
    const getAccountsWithDeposits = (userDeposits) =>
      Array.from(new Set(userDeposits.map(({ account }) => account)).values());
    const getUserDepositParams = (symbols) => {
      const userDeposits = symbols.flatMap((symbol) =>
        newArray(3, () => ({
          symbol,
          amount: randomInt(100, 1000),
          account: accounts[randomInt(1, 4)],
        }))
      );

      return {
        userDeposits,
        accountsWithDeposits: getAccountsWithDeposits(userDeposits),
        tokenContracts: {},
      };
    };
    const setUpUserDeposits = (userDeposits, tokenContracts = {}) => {
      const accountsWithDeposits = getAccountsWithDeposits(userDeposits);

      return setUpMultipleTokenAdapters()
        .then(() =>
          useMethodOn(FUSDTokenSale, {
            method: 'getTokenAdapterAddresses',
            onReturn: () => {},
          })
        )
        .then((tokenAdapterAddresses) =>
          runPromisesInSequence(
            tokenAdapterAddresses.map(() => async (_, i) => {
              const { Token, tokenSymbol } =
                await getTokenContractAndSymbolFromAdapter(
                  tokenAdapterAddresses[i]
                );
              tokenContracts[tokenSymbol] = Token;

              const userTokenDeposits = accountsWithDeposits
                .map((account) => ({
                  account,
                  amount: userDeposits
                    .filter(
                      ({ account: depositAccount, symbol }) =>
                        account === depositAccount && symbol === tokenSymbol
                    )
                    .reduce((acc, { amount }) => acc + amount, 0),
                }))
                .filter(({ amount }) => amount > 0);

              return useMethodsOn(
                Token,
                userTokenDeposits.flatMap(({ amount, account }) => [
                  {
                    method: 'mint',
                    args: [account, amount],
                    account: accounts[0],
                  },
                  {
                    method: 'approve',
                    args: [FUSDTokenSale.options.address, amount],
                    account,
                  },
                ])
              );
            })
          )
        )
        .then(() =>
          Object.fromEntries(
            Object.entries(tokenContracts).map(([symbol, token]) => [
              symbol,
              token.options.address,
            ])
          )
        )
        .then((tokenAddresses) =>
          useMethodsOn(
            FUSDTokenSale,
            userDeposits.map(({ symbol, amount, account }) => ({
              method: 'deposit',
              args: [tokenAddresses[symbol], amount],
              account,
            }))
          )
        );
    };

    it('allows users to deposit erc20 tokens', () => {
      const { userDeposits, accountsWithDeposits, tokenContracts } =
        getUserDepositParams(symbols);

      const totalToDeposit = Object.fromEntries(
        symbols.map((symbol) => [
          symbol,
          userDeposits
            .filter(({ symbol: depositSymbol }) => symbol === depositSymbol)
            .reduce((acc, { amount }) => acc + amount, 0),
        ])
      );

      const totalDeposited = Object.fromEntries(
        symbols.map((symbol) => [symbol, 0])
      );

      return setUpUserDeposits(userDeposits, tokenContracts)
        .then(() =>
          useMethodsOn(
            FUSDTokenSale,
            accountsWithDeposits.map((account) => ({
              method: 'getUserTokenBalances',
              args: [account],
              onReturn: (result) => {
                const deposited = result[0].map((amount) => parseInt(amount));
                const symbols = result[1];

                symbols.forEach((s, i) => {
                  totalDeposited[s] += deposited[i];
                });
              },
            }))
          )
        )
        .then(() => {
          assert.deepStrictEqual(totalDeposited, totalToDeposit);
        })
        .then(() =>
          runPromisesInSequence(
            Object.entries(tokenContracts).map(
              ([symbol, token]) =>
                () =>
                  useMethodOn(token, {
                    method: 'balanceOf',
                    args: [FUSDTokenSale.options.address],
                    onReturn: (balance) => {
                      assert.strictEqual(
                        parseInt(balance),
                        totalToDeposit[symbol]
                      );
                    },
                  })
            )
          )
        );
    });

    it('throws error if user tries to deposit non-supported token', async () => {
      const erc20Token = await deploy(
        erc20TokenContract,
        [erc20TokenName, 'USDT', erc20TokenDecimals],
        accounts[0]
      );

      let errorRaised = false;

      return useMethodOn(FUSDTokenSale, {
        method: 'deposit',
        args: [erc20Token.options.address, 100],
        account: accounts[0],
        catch: (error) => {
          errorRaised = true;
          assert.strictEqual(error, 'Token adapter does not exist');
        },
      }).then(() => {
        assert.ok(errorRaised);
      });
    });

    it('allows users to withdraw erc20 tokens', () => {
      const { userDeposits, tokenContracts } = getUserDepositParams(symbols);

      const totalUserDeposits = getAccountsWithDeposits(userDeposits).flatMap(
        (account) =>
          symbols
            .map((symbol) => ({
              account,
              symbol,
              totalDeposit: userDeposits
                .filter(
                  ({ account: depositAccount, symbol: depositSymbol }) =>
                    account === depositAccount && symbol === depositSymbol
                )
                .reduce((acc, { amount }) => acc + amount, 0),
            }))
            .filter(({ amount }) => amount > 0)
      );

      return setUpUserDeposits(userDeposits, tokenContracts)
        .then(() =>
          useMethodsOn(
            FUSDTokenSale,
            userDeposits.map(({ symbol, account, amount }) => ({
              method: 'withdraw',
              args: [tokenContracts[symbol].options.address, amount],
              account,
            }))
          )
        )
        .then(() =>
          runPromisesInSequence(
            Object.values(tokenContracts).map(
              (token) => () =>
                useMethodOn(token, {
                  method: 'balanceOf',
                  args: [FUSDTokenSale.options.address],
                  onReturn: (balance) => {
                    assert.strictEqual(parseInt(balance), 0);
                  },
                })
            )
          )
        )
        .then(() =>
          runPromisesInSequence(
            totalUserDeposits.map(
              ({ symbol, account, totalDeposit }) =>
                () =>
                  useMethodOn(tokenContracts[symbol], {
                    method: 'balanceOf',
                    args: [account],
                    onReturn: (balance) => {
                      assert.strictEqual(parseInt(balance), totalDeposit);
                    },
                  })
            )
          )
        );
    });

    it('throws error if user tries to withdraw more than deposited', () => {
      const { userDeposits, tokenContracts } = getUserDepositParams(symbols);

      let errorRaised = false;

      return setUpUserDeposits(userDeposits, tokenContracts)
        .then(() =>
          useMethodOn(FUSDTokenSale, {
            method: 'withdraw',
            args: [tokenContracts[symbols[0]].options.address, 2000],
            account: accounts[0],
            catch: (error) => {
              errorRaised = true;
              assert.strictEqual(
                error,
                'ERC20ExchangeVault: insufficient balance'
              );
            },
          })
        )
        .then(() => {
          assert.ok(errorRaised);
        });
    });
  });
});
