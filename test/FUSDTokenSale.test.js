const assert = require('assert');
const contracts = require('../compile');
const {
  deploy,
  getAccounts,
  getDeployedContract,
} = require('../utils/useWeb3');
const {
  timeInSecs,
  randomInt,
  newArray,
  runPromisesInSequence,
  randomElement,
  mapObject,
} = require('../utils/helper');
const {
  useMethodsOn,
  useMethodOn,
  getContractEvents,
  compiledContractMap,
} = require('../utils/contracts');
const OldVersionCompiler = require('../utils/OldVersionCompiler');

const erc20TokenContract = contracts['ERC20Token.sol'].ERC20Token;
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
const annualInterestRate = 8 * 10;
const minCollateralRatio = 150 * 10;
const liquidationPenalty = 12 * 10;

const symbols = ['USDT', 'USDC', 'DAI'];

describe('FUSDTokenSale tests', () => {
  let accounts,
    getOldVersionContract,
    withdrawableAddress,
    FUSDToken,
    FUSDTokenSale,
    ERC20Token,
    DIAOracleV2,
    DIAOracleV2TokenAdapter;

  before(async () => {
    getOldVersionContract = compiledContractMap(await OldVersionCompiler.get());
  });

  beforeEach(async () => {
    accounts = await getAccounts();
    withdrawableAddress = accounts[8];
    FUSDToken = await deploy(fusdTokenContract, [], accounts[0]);
    FUSDTokenSale = await deploy(
      tokenSaleContract,
      [
        FUSDToken.options.address,
        annualInterestRate, // In the contract the annual interest rate is represented by tenths of a percent (1 = 0.1%)
        minCollateralRatio,
        liquidationPenalty,
        withdrawableAddress,
      ],
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
    // We set the value for the token symbol we are using in the tests
    useMethodOn(DIAOracleV2, {
      method: 'setValue',
      args: [`${erc20TokenSymbol}/USD`, 1 * 10 ** usdValDecimals, timeInSecs()],
      account: accounts[0],
    })
      .then(() =>
        // We deploy the token adapter contract with the oracle and token addresses.
        // The oracle must have a value for the token symbol we are using in the tests
        deploy(
          adapterContract,
          [DIAOracleV2.options.address, ERC20Token.options.address],
          accounts[0]
        )
      )
      .then((tokenAdapter) => {
        // We assign the adapter
        DIAOracleV2TokenAdapter = tokenAdapter;
      });

  /**
   * Generates random decimal and oracle values for each token symbol
   */
  const generateERC20Params = () =>
    symbols.reduce((params, symbol) => {
      params[symbol] = {
        decimals: randomInt(8, 12),
        usdOracleValue: randomInt(1, 100) * 10 ** usdValDecimals,
      };
      return params;
    }, {});

  /**
   * Depoloys erc20 contract, sets oracle value, deploys and registers token adapter
   * for each token in the provided params
   */
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
      Object.entries(params).map(([symbol, { usdOracleValue }]) => ({
        // We set the value in the oracle for the
        // token symbol we are using in the tests
        method: 'setValue',
        args: [`${symbol}/USD`, usdOracleValue, timeInSecs()],
        account: accounts[0],
      }))
    )
      .then(() =>
        Promise.all(
          ERC20Tokens.map((token) =>
            // We deploy the token adapter contract with the oracle and token addresses.
            // The oracle must have a value for the token symbol we are using in the tests
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
            // We register the token adapter in the token sale contract
            method: 'addTokenAdapter',
            args: [tokenAdapter.options.address],
            account: accounts[0],
          })),
        ])
      );
  };

  /**
   * Returns the token contract and symbol from the adapter address
   */
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

  /**
   * Returns an array of unique accounts with deposits
   */
  const getAccountsWithDeposits = (userDeposits) =>
    Array.from(new Set(userDeposits.map(({ account }) => account)).values());

  /**
   * Sets up oracles, token adapters, send user tokens and approves them for the token sale contract
   */
  const setUpUserTokens = (
    userTokens,
    tokenContracts = {},
    erc20Params = generateERC20Params()
  ) => {
    const accountsWithDeposits = getAccountsWithDeposits(userTokens);

    return setUpMultipleTokenAdapters(erc20Params)
      .then(() =>
        useMethodOn(FUSDTokenSale, {
          // We get an array of all token adapter addresses
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
            // For each token adapter we get the token contract reference and symbol
            // and we store them in the tokenContracts object
            tokenContracts[tokenSymbol] = Token;

            const userTokenDeposits = accountsWithDeposits
              .map((account) => ({
                account,
                amount: userTokens
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
                  // We provide each user with the amount of tokens they need
                  method: 'mint',
                  args: [account, amount],
                  account: accounts[0],
                },
                {
                  // And each user approves the token sale contract to spend their tokens
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
      );
  };

  /**
   * Generates random user deposits and loans
   */
  const generateUserDepositsAndLoans = () =>
    newArray(5, () => ({
      symbol: randomElement(symbols),
      amount: randomInt(5000, 10000),
      loanAmount: randomInt(500, 1000),
      account: randomElement(accounts),
    }));

  /**
   * Sets up oracles, token adapters, send user tokens and approves them for the token sale contract
   * Users deposit tokens in the token sale contract and borrow FUSD
   */
  const setUpUserCollateralAndLoans = (
    userDepositsAndLoans = generateUserDepositsAndLoans(),
    tokenContracts = {},
    erc20Params = generateERC20Params()
  ) =>
    setUpUserTokens(userDepositsAndLoans, tokenContracts, erc20Params)
      .then((tokenAddresses) =>
        useMethodOn(FUSDToken, {
          // The owner sets the token sale contract as a minter
          // so it can mint FUSD for users
          method: 'setIsMinter',
          args: [FUSDTokenSale.options.address, true],
          account: accounts[0],
        }).then(() => tokenAddresses)
      )
      .then((tokenAddresses) =>
        useMethodsOn(
          FUSDTokenSale,
          userDepositsAndLoans.map(
            ({ symbol, amount, loanAmount, account }) => ({
              // Each user deposits tokens and borrows FUSD with one method call
              method: 'depositTokenAndBorrowFUSD',
              args: [tokenAddresses[symbol], amount, loanAmount],
              account,
            })
          )
        )
      );

  /**
   * Returns a random user and their total loan amount
   * from the provided user deposit and loan params
   */
  const getRandomUserAndLoanAmount = (userDepositParams) => {
    const userToPayOffDebt = randomElement(
      getAccountsWithDeposits(userDepositParams)
    );
    const totalUserLoanAmount = userDepositParams
      .filter(({ account }) => account === userToPayOffDebt)
      .reduce((acc, { loanAmount }) => acc + loanAmount, 0);

    return { userToPayOffDebt, totalUserLoanAmount };
  };

  const formatTokenBalances = (balances, symbols) =>
    balances.reduce((obj, balance, i) => {
      obj[symbols[i]] = parseInt(balance);
      return obj;
    }, {});

  describe('FUSDTokenSale', () => {
    it('deploys successfully', () => {
      assert.ok(FUSDTokenSale.options.address);
    });

    it('allows user to pay off part of debt', () => {
      const userDepositsAndLoans = generateUserDepositsAndLoans();
      const { userToPayOffDebt, totalUserLoanAmount } =
        getRandomUserAndLoanAmount(userDepositsAndLoans);
      const amountToPayOff = Math.ceil(totalUserLoanAmount / 2);
      const amountLeft = totalUserLoanAmount - amountToPayOff;

      return setUpUserCollateralAndLoans(userDepositsAndLoans)
        .then(() =>
          useMethodOn(FUSDToken, {
            // User approves the token sale contract to spend half of the debt
            method: 'approve',
            args: [FUSDTokenSale.options.address, amountToPayOff],
            account: userToPayOffDebt,
          })
        )
        .then(() =>
          useMethodsOn(FUSDTokenSale, [
            {
              // User pays off half of the debt
              method: 'payOffDebt',
              args: [amountToPayOff],
              account: userToPayOffDebt,
            },
            {
              // We get the total debt for the account
              method: 'getTotalDebt',
              args: [userToPayOffDebt],
              onReturn: (totalDebt) => {
                // and check that half of the debt has been paid off
                assert.strictEqual(parseInt(totalDebt), amountLeft);
              },
            },
          ])
        );
    });

    it('allows user to pay off all of debt', () => {
      const userDepositsAndLoans = generateUserDepositsAndLoans();
      const { userToPayOffDebt, totalUserLoanAmount } =
        getRandomUserAndLoanAmount(userDepositsAndLoans);

      return setUpUserCollateralAndLoans(userDepositsAndLoans)
        .then(() =>
          useMethodOn(FUSDToken, {
            // User approves the token sale contract to spend all of the debt
            method: 'approve',
            args: [FUSDTokenSale.options.address, totalUserLoanAmount],
            account: userToPayOffDebt,
          })
        )
        .then(() =>
          useMethodsOn(FUSDTokenSale, [
            {
              // User pays off all of the debt
              method: 'payOffAllDebt',
              account: userToPayOffDebt,
            },
            {
              method: 'getTotalDebt',
              args: [userToPayOffDebt],
              onReturn: (totalDebt) => {
                // We get the total debt for the account
                // and check that all of the debt has been paid off
                assert.strictEqual(parseInt(totalDebt), 0);
              },
            },
          ])
        );
    });

    it('allows user to borrow FUSD if collateral ratio is safe', () => {
      // We deposit 150 USDT and borrow 50 FUSD, which allows us to borrow
      // another 50 FUSD without making our collateral ratio unsafe
      const amountToDeposit = 150;
      const amountToBorrow = 50;

      const userDepositsAndLoans = [
        {
          symbol: 'USDT',
          amount: amountToDeposit,
          loanAmount: amountToBorrow,
          account: accounts[1],
        },
      ];

      const erc20Params = {
        USDT: {
          decimals: 18,
          usdOracleValue: 1 * 10 ** usdValDecimals,
        },
      };

      return setUpUserCollateralAndLoans(
        userDepositsAndLoans,
        {},
        erc20Params
      ).then(() =>
        useMethodsOn(FUSDTokenSale, [
          {
            // User borrows FUSD
            method: 'borrowFUSD',
            args: [amountToBorrow],
            account: accounts[1],
          },
          {
            // We get the total debt for the account
            method: 'getTotalDebt',
            args: [accounts[1]],
            onReturn: (totalDebt) => {
              // and check that the debt has been updated
              assert.strictEqual(parseInt(totalDebt), amountToBorrow * 2);
            },
          },
        ])
      );
    });

    it('throws error if user tries to borrow FUSD and make collateral ratio unsafe', () => {
      // We deposit 150 USDT and borrow 100 FUSD, which makes our collateral ratio
      // right on the edge of being unsafe. We expect an error to be thrown if we
      // try to borrow more FUSD and make our collateral ratio unsafe
      const amountToDeposit = 150;
      const amountToBorrow = 100;

      const userDepositsAndLoans = [
        {
          symbol: 'USDT',
          amount: amountToDeposit,
          loanAmount: amountToBorrow,
          account: accounts[1],
        },
      ];

      const erc20Params = {
        USDT: {
          decimals: 18,
          usdOracleValue: 1 * 10 ** usdValDecimals,
        },
      };

      let errorRaised = false;

      return setUpUserCollateralAndLoans(userDepositsAndLoans, {}, erc20Params)
        .then(() =>
          useMethodOn(FUSDTokenSale, {
            method: 'borrowFUSD',
            args: [amountToBorrow],
            account: accounts[1],
            catch: (error) => {
              // We expect an error to be thrown if the user tries to borrow FUSD
              // and make their collateral ratio unsafe
              errorRaised = true;
              assert.strictEqual(
                error,
                'FUSDTokenSale: collateral ratio is unsafe'
              );
            },
          })
        )
        .then(() => {
          // We check that the error was raised
          assert.ok(errorRaised);
        });
    });

    it('allows user to withdraw tokens if collateral ratio is safe', () => {
      // We deposit 200 USDT and borrow 100 FUSD, which allows us to withdraw
      // 50 USDT without making our collateral ratio unsafe
      const tokenToWithdraw = 'USDT';
      const initialDepositAmount = 200;
      const amountToWithdraw = 50;
      const userDepositsAndLoans = [
        {
          symbol: tokenToWithdraw,
          amount: initialDepositAmount,
          loanAmount: 100,
          account: accounts[1],
        },
      ];

      const tokenContracts = {};

      const erc20Params = {
        [tokenToWithdraw]: {
          decimals: 18,
          usdOracleValue: 1 * 10 ** usdValDecimals,
        },
      };

      return setUpUserCollateralAndLoans(
        userDepositsAndLoans,
        tokenContracts,
        erc20Params
      ).then(() =>
        useMethodsOn(FUSDTokenSale, [
          {
            // User withdraws tokens
            method: 'withdrawToken',
            args: [
              tokenContracts[tokenToWithdraw].options.address,
              amountToWithdraw,
            ],
            account: accounts[1],
          },
          {
            // We get the token balance for the account
            method: 'getUserTokenBalance',
            args: [
              accounts[1],
              tokenContracts[tokenToWithdraw].options.address,
            ],
            onReturn: (tokenBalance) => {
              // and check that the balance has been updated correctly
              assert.strictEqual(
                parseInt(tokenBalance),
                initialDepositAmount - amountToWithdraw
              );
            },
          },
        ])
      );
    });

    it('throws error on token withdrawal if collateral ratio is unsafe', () => {
      // We deposit 150 USDT and borrow 100 FUSD, which makes our collateral ratio
      // right on the edge of being unsafe. We expect an error to be thrown if we
      // try to withdraw tokens and make our collateral ratio unsafe
      const tokenToWithdraw = 'USDT';
      const initialDepositAmount = 150;
      const amountToWithdraw = 50;
      const userDepositsAndLoans = [
        {
          symbol: tokenToWithdraw,
          amount: initialDepositAmount,
          loanAmount: 100,
          account: accounts[1],
        },
      ];

      const tokenContracts = {};

      const erc20Params = {
        [tokenToWithdraw]: {
          decimals: 18,
          usdOracleValue: 1 * 10 ** usdValDecimals,
        },
      };

      let errorRaised = false;

      return setUpUserCollateralAndLoans(
        userDepositsAndLoans,
        tokenContracts,
        erc20Params
      )
        .then(() =>
          useMethodOn(FUSDTokenSale, {
            // User tries to withdraw tokens
            method: 'withdrawToken',
            args: [
              tokenContracts[tokenToWithdraw].options.address,
              amountToWithdraw,
            ],
            account: accounts[1],
            catch: (error) => {
              // We expect an error to be thrown if the user tries to withdraw tokens
              // and make their collateral ratio unsafe
              errorRaised = true;
              assert.strictEqual(
                error,
                'FUSDTokenSale: collateral ratio is unsafe'
              );
            },
          })
        )
        .then(() => {
          // We check that the error was raised
          assert.ok(errorRaised);
        });
    });

    it('throws error if non owner tries to update CR params', async () => {
      let errorsRaised = 0;
      const methods = [
        'setMinCollateralRatioForLoanTenthPerc',
        'setLiquidationPenaltyTenthPerc',
        'setAnnualInterestRateTenthPerc',
      ];

      return useMethodsOn(
        FUSDTokenSale,
        methods.map((method) => ({
          method,
          args: [100 * 10],
          account: accounts[1],
          catch: (_, data) => {
            assert.strictEqual(
              data.slice(0, 32),
              // OwnableUnauthorizedAccount error signature
              '0x118cdaa70000000000000000000000'
            );
            errorsRaised++;
          },
        }))
      ).then(() => {
        // We check that the error was raised
        assert.strictEqual(errorsRaised, methods.length);
      });
    });

    it('calculates max FUSD to borrow', () => {
      const symbol = 'USDT';

      const userDepositParams = [
        {
          deposit: 1500,
          loan: 1000,
          expectedMaxFUSDToBorrow: 0,
        },
        {
          deposit: 1500,
          loan: 500,
          expectedMaxFUSDToBorrow: 500,
        },
        {
          deposit: 3000,
          loan: 500,
          expectedMaxFUSDToBorrow: 1500,
        },
        {
          deposit: 3000,
          loan: 1666,
          expectedMaxFUSDToBorrow: 334,
        },
      ].map(({ deposit, loan, ...rest }, i) => ({
        symbol,
        amount: deposit,
        loanAmount: loan,
        account: accounts[i + 1],
        ...rest,
      }));
      const erc20Params = {
        [symbol]: {
          decimals: 18,
          usdOracleValue: 1 * 10 ** usdValDecimals,
        },
      };

      return setUpUserCollateralAndLoans(userDepositParams, {}, erc20Params)
        .then(() =>
          useMethodsOn(
            FUSDTokenSale,
            userDepositParams.map(({ account, expectedMaxFUSDToBorrow }) => ({
              // For each user we calculate the max FUSD they can borrow
              method: 'calculateMaxFUSDToBorrow',
              args: [account],
              onReturn: (maxFUSDToBorrow) => {
                // and check that the value matches the expected value
                assert.strictEqual(
                  parseInt(maxFUSDToBorrow),
                  expectedMaxFUSDToBorrow
                );
              },
            }))
          )
        )
        .then(() =>
          useMethodOn(DIAOracleV2, {
            // We simulate a dramatic price drop for the token
            // so the user falls below the min collateral ratio
            method: 'setValue',
            args: [
              `${symbol}/USD`,
              0.0001 * 10 ** usdValDecimals,
              timeInSecs(),
            ],
            account: accounts[0],
          })
        )
        .then(() =>
          useMethodOn(FUSDTokenSale, {
            // We calculate the max FUSD to borrow for the user
            method: 'calculateMaxFUSDToBorrow',
            args: [accounts[1]],
            onReturn: (maxCollateralToWithdraw) => {
              // and check that the value is 0
              assert.strictEqual(parseInt(maxCollateralToWithdraw), 0);
            },
          })
        );
    });

    it('calculates max collateral to withdraw', () => {
      const symbol = 'USDT';

      const userDepositParams = [
        {
          deposit: 1500,
          loan: 1000,
          expectedMaxCollateralToWithdraw: 0,
        },
        {
          deposit: 1500,
          loan: 500,
          expectedMaxCollateralToWithdraw: 750,
        },
        {
          deposit: 800,
          loan: 500,
          expectedMaxCollateralToWithdraw: 50,
        },
        {
          deposit: 3000,
          loan: 1400,
          expectedMaxCollateralToWithdraw: 900,
        },
      ].map(({ deposit, loan, ...rest }, i) => ({
        symbol,
        amount: deposit,
        loanAmount: loan,
        account: accounts[i + 1],
        ...rest,
      }));
      const erc20Params = {
        [symbol]: {
          decimals: 18,
          usdOracleValue: 1 * 10 ** usdValDecimals,
        },
      };

      return setUpUserCollateralAndLoans(userDepositParams, {}, erc20Params)
        .then(() =>
          useMethodsOn(
            FUSDTokenSale,
            userDepositParams.map(
              ({ account, expectedMaxCollateralToWithdraw }) => ({
                // For each user we calculate the max collateral they can withdraw
                method: 'calculateMaxCollateralToWithdraw',
                args: [account],
                onReturn: (maxCollateralToWithdraw) => {
                  assert.strictEqual(
                    parseInt(maxCollateralToWithdraw),
                    expectedMaxCollateralToWithdraw
                  );
                },
              })
            )
          )
        )
        .then(() =>
          useMethodOn(DIAOracleV2, {
            // We simulate a dramatic price drop for the token
            // so the user falls below the min collateral ratio
            method: 'setValue',
            args: [
              `${symbol}/USD`,
              0.0001 * 10 ** usdValDecimals,
              timeInSecs(),
            ],
            account: accounts[0],
          })
        )
        .then(() =>
          useMethodOn(FUSDTokenSale, {
            // We calculate the max collateral to withdraw for the user
            method: 'calculateMaxCollateralToWithdraw',
            args: [accounts[1]],
            onReturn: (maxCollateralToWithdraw) => {
              // and check that the value is 0
              assert.strictEqual(parseInt(maxCollateralToWithdraw), 0);
            },
          })
        );
    });

    it('calculates max collateral tokens to withdraw', () => {
      const tokenToUsd = {
        USDT: 0.5,
        USDC: 1,
        DAI: 2,
      };
      const erc20Params = mapObject(tokenToUsd, (usdOracleValue) => ({
        decimals: 18,
        usdOracleValue: usdOracleValue * 10 ** usdValDecimals,
      }));

      const userDepositParams = [
        {
          symbol: 'USDT',
          amount: 3000,
          loanAmount: 500,
          account: accounts[1],
        },
        {
          symbol: 'USDC',
          amount: 2500,
          loanAmount: 1000,
          account: accounts[2],
        },
        {
          symbol: 'DAI',
          amount: 4500,
          loanAmount: 2000,
          account: accounts[3],
        },
        {
          symbol: 'USDT',
          amount: 2000,
          loanAmount: 500,
          account: accounts[4],
        },
        {
          symbol: 'USDC',
          amount: 2000,
          loanAmount: 500,
          account: accounts[4],
        },
        {
          symbol: 'DAI',
          amount: 2000,
          loanAmount: 500,
          account: accounts[4],
        },
      ];
      const expectedMaxTokensToWithdraw = {
        [accounts[1]]: {
          USDT: 1500,
          USDC: 0,
          DAI: 0,
        },
        [accounts[2]]: {
          USDT: 0,
          USDC: 1000,
          DAI: 0,
        },
        [accounts[3]]: {
          USDT: 0,
          USDC: 0,
          DAI: 3000,
        },
        [accounts[4]]: {
          USDT: 2000,
          USDC: 2000,
          DAI: 2000,
        },
      };

      const users = getAccountsWithDeposits(userDepositParams);
      const tokenContracts = {};

      return setUpUserCollateralAndLoans(
        userDepositParams,
        tokenContracts,
        erc20Params
      )
        .then(() =>
          useMethodsOn(
            FUSDTokenSale,
            users.flatMap((account) => [
              {
                // For each user we calculate the max collateral tokens they can withdraw
                method: 'calculateMaxTokensToWithdraw',
                args: [account],
                onReturn: (result) => {
                  const maxTokensToWithdraw = formatTokenBalances(
                    result[0],
                    result[1]
                  );

                  // and check that the value matches the expected value
                  assert.deepStrictEqual(
                    maxTokensToWithdraw,
                    expectedMaxTokensToWithdraw[account]
                  );
                },
              },
            ])
          )
        )
        .then(() =>
          useMethodsOn(
            DIAOracleV2,
            Object.keys(erc20Params).map((symbol) => ({
              // We simulate a dramatic price drop for the token
              // so the user falls below the min collateral ratio
              method: 'setValue',
              args: [
                `${symbol}/USD`,
                0.0001 * 10 ** usdValDecimals,
                timeInSecs(),
              ],
              account: accounts[0],
            }))
          )
        )
        .then(() =>
          useMethodsOn(
            FUSDTokenSale,
            users.map((account) => ({
              method: 'calculateMaxTokensToWithdraw',
              args: [account],
              onReturn: (result) => {
                const maxTokensToWithdraw = formatTokenBalances(
                  result[0],
                  result[1]
                );

                // Since the user is below the min collateral ratio
                // we expect the max collateral tokens to withdraw to be 0
                assert.deepStrictEqual(
                  maxTokensToWithdraw,
                  mapObject(tokenToUsd, () => 0)
                );
              },
            }))
          )
        );
    });

    describe('throws error if min collateral ratio is lower than liquidation threshold', async () => {
      const expectedError =
        'FUSDTokenSale: Liquidation threshold must be below minimum collateral ratio';

      it('on deployment', async () => {
        let errorRaised = false;

        await deploy(
          tokenSaleContract,
          [
            FUSDToken.options.address,
            annualInterestRate, // In the contract the annual interest rate is represented by tenths of a percent (1 = 0.1%)
            100 * 10, // min collateral ratio
            12 * 10, // liquidation penalty
            withdrawableAddress,
          ],
          accounts[0]
        ).catch((error) => {
          // We expect an error to be thrown if the min collateral ratio is lower than
          // the liquidation threshold on deployment
          errorRaised = true;
          assert.ok(error);
        });

        // We check that the error was raised
        assert.ok(errorRaised);
      });

      it('on updating min collateral ratio', async () => {
        let errorRaised = false;

        return useMethodOn(FUSDTokenSale, {
          // LT 100.0% + 8.0% + 12.0% = 120.0%
          // Min CR 100.0%
          method: 'setMinCollateralRatioForLoanTenthPerc',
          args: [100 * 10],
          account: accounts[0],
          catch: (error) => {
            errorRaised = true;
            assert.strictEqual(error, expectedError);
          },
        }).then(() => {
          // We check that the error was raised
          assert.ok(errorRaised);
        });
      });

      it('on updating annual interest rate', async () => {
        let errorRaised = false;

        return useMethodsOn(FUSDTokenSale, [
          {
            // LT 100.0% + 50.0% + 12.0% = 162.0%
            // Min CR 150.0%
            method: 'setAnnualInterestRateTenthPerc',
            args: [50 * 10],
            account: accounts[0],
            catch: (error) => {
              errorRaised = true;
              assert.strictEqual(error, expectedError);
            },
          },
        ]).then(() => {
          // We check that the error was raised
          assert.ok(errorRaised);
        });
      });

      it('on updating liquidation penalty', async () => {
        let errorRaised = false;

        return useMethodsOn(FUSDTokenSale, [
          {
            // LT 100.0% + 8.0% + 50.0% = 158.0%
            // Min CR 150.0%
            method: 'setLiquidationPenaltyTenthPerc',
            args: [50 * 10],
            account: accounts[0],
            catch: (error) => {
              errorRaised = true;
              assert.strictEqual(error, expectedError);
            },
          },
        ]).then(() => {
          // We check that the error was raised
          assert.ok(errorRaised);
        });
      });
    });
  });

  describe('StoringERC20WithdrawableAddress', () => {
    it('returns withdrawable address', () =>
      useMethodOn(FUSDTokenSale, {
        // We get the withdrawable address
        method: 'getERC20WithdrawableAddress',
        onReturn: (wAddress) => {
          // and check that it matches the one we set on deployment
          assert.strictEqual(wAddress, withdrawableAddress);
        },
      }));

    it('allows owner to update withdrawable address', () => {
      const newWithdrawableAddress = accounts[9];

      return useMethodsOn(FUSDTokenSale, [
        {
          // Owner updates the withdrawable address
          method: 'setERC20WithdrawableAddress',
          args: [newWithdrawableAddress],
          account: accounts[0],
        },
        {
          // We check that the withdrawable address has been updated
          method: 'getERC20WithdrawableAddress',
          onReturn: (wAddress) => {
            assert.strictEqual(wAddress, newWithdrawableAddress);
          },
        },
      ]);
    });
  });

  describe('CollateralRatioCalculator', () => {
    it('returns minimum collateral ratio for loan', () =>
      useMethodOn(FUSDTokenSale, {
        // We get the minimum collateral ratio for loan
        method: 'getMinCollateralRatioForLoanTenthPerc',
        onReturn: (minCR) => {
          // and check that it matches the one we set on deployment
          assert.strictEqual(parseInt(minCR), minCollateralRatio);
        },
      }));

    it('returns liquidation penalty', () =>
      useMethodOn(FUSDTokenSale, {
        // We get the liquidation penalty
        method: 'getLiquidationPenaltyTenthPerc',
        onReturn: (lp) => {
          // and check that it matches the one we set on deployment
          assert.strictEqual(parseInt(lp), liquidationPenalty);
        },
      }));

    it('allows owner to update minimum collateral ratio for loan', () => {
      const newMinCR = 200 * 10;

      return useMethodsOn(FUSDTokenSale, [
        {
          // Owner updates the minimum collateral ratio for loan
          method: 'setMinCollateralRatioForLoanTenthPerc',
          args: [newMinCR],
          account: accounts[0],
        },
        {
          // We check that the minimum collateral ratio for loan has been updated...
          method: 'getMinCollateralRatioForLoanTenthPerc',
          onReturn: (minCR) => {
            // ...correctly
            assert.strictEqual(parseInt(minCR), newMinCR);
          },
        },
      ]);
    });

    it('allows owner to update liquidation penalty', () => {
      const newLP = 20 * 10;

      return useMethodsOn(FUSDTokenSale, [
        {
          // Owner updates the liquidation penalty
          method: 'setLiquidationPenaltyTenthPerc',
          args: [newLP],
          account: accounts[0],
        },
        {
          // We check that the liquidation penalty has been updated...
          method: 'getLiquidationPenaltyTenthPerc',
          onReturn: (lp) => {
            // ...correctly
            assert.strictEqual(parseInt(lp), newLP);
          },
        },
      ]);
    });
  });

  describe('TokenAdapterFactory', () => {
    it('allows to add a token adapter reference', () =>
      // We first set up the oracle
      setUpOracle().then(() =>
        useMethodsOn(FUSDTokenSale, [
          {
            // Owner adds the token adapter
            method: 'addTokenAdapter',
            args: [DIAOracleV2TokenAdapter.options.address],
            account: accounts[0],
          },
          {
            method: 'getTokenAdapterAddresses',
            onReturn: ([tokenAdapterAddress]) => {
              // We get an array of all token adapter addresses
              // and check that the one we added is included
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
            // We get an array of all token symbols
            // and check that it matches the symbols we used in the tests
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
                // We expect an error to be thrown if we try to add
                // a token adapter for a token symbol that already exists.
                // There can only be one token adapter per token symbol
                errorRaised = true;
                assert.strictEqual(error, 'Token adapter already exists');
              },
            },
          ])
        )
        .then(() => {
          // We check that the error was raised
          assert.ok(errorRaised);
        });
    });
  });

  describe('ERC20ExchangeVault', () => {
    /**
     * Returns an object with user deposits, accounts with deposits and token contracts
     */
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

    /**
     * Sets up oracles, token adapters, send user tokens and approves them for the token sale contract
     * Users deposit tokens in the token sale contract
     */
    const setUpUserDeposits = (userDeposits, tokenContracts = {}) =>
      setUpUserTokens(userDeposits, tokenContracts).then((tokenAddresses) =>
        useMethodsOn(
          FUSDTokenSale,
          userDeposits.map(({ symbol, amount, account }) => ({
            method: 'depositToken',
            args: [tokenAddresses[symbol], amount],
            account,
          }))
        )
      );

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
              // We get the user deposited token balances
              method: 'getUserTokenBalances',
              args: [account],
              onReturn: (result) => {
                const deposited = result[0].map((amount) => parseInt(amount));
                const symbols = result[1];

                symbols.forEach((s, i) => {
                  const expectedDeposit = userDeposits
                    .filter(
                      ({ account: depositAccount, symbol: depositSymbol }) =>
                        account === depositAccount && s === depositSymbol
                    )
                    .reduce((acc, { amount }) => acc + amount, 0);

                  // We check that the total deposited token amount
                  assert.strictEqual(deposited[i], expectedDeposit);
                  // And we add it to the total deposited amount for this token
                  totalDeposited[s] += deposited[i];
                });
              },
            }))
          )
        )
        .then(() => {
          // We check that the total deposited amount for each token matches
          // the expected total deposited amount
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
                      // We also check that the token sale contract balance
                      // matches the expected total deposited amount
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

    it('returns user total token deposit', () => {
      const { userDeposits, accountsWithDeposits, tokenContracts } =
        getUserDepositParams(symbols);
      const accountToCheck = accountsWithDeposits[0];
      const { symbol: tokenToCheck } = userDeposits.find(
        ({ account }) => account === accountToCheck
      );
      const totalDeposit = userDeposits
        .filter(
          ({ account, symbol }) =>
            account === accountToCheck && symbol === tokenToCheck
        )
        .reduce((acc, { amount }) => acc + amount, 0);

      return setUpUserDeposits(userDeposits, tokenContracts).then(() =>
        useMethodOn(FUSDTokenSale, {
          // We get the user total token deposit
          method: 'getUserTokenBalance',
          args: [accountToCheck, tokenContracts[tokenToCheck].options.address],
          onReturn: (balance) => {
            // and check that it matches the expected total deposit
            assert.strictEqual(parseInt(balance), totalDeposit);
          },
        })
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
        method: 'depositToken',
        args: [erc20Token.options.address, 100],
        account: accounts[0],
        catch: (error) => {
          // We expect an error to be thrown if the user tries to deposit
          // a token that is not supported by the token sale contract
          errorRaised = true;
          assert.strictEqual(error, 'Token adapter does not exist');
        },
      }).then(() => {
        // We check that the error was raised
        assert.ok(errorRaised);
      });
    });

    it('allows users to withdraw erc20 tokens', () => {
      const { userDeposits, tokenContracts } = getUserDepositParams(symbols);

      // We calculate total deposited amount per each user and token
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

      // Each user deposits the planned amount of tokens
      return setUpUserDeposits(userDeposits, tokenContracts)
        .then(() =>
          useMethodsOn(
            FUSDTokenSale,
            userDeposits.map(({ symbol, account, amount }) => ({
              // And then withdraws the deposited amount
              method: 'withdrawToken',
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
                    // We check that the token sale contract balance
                    // is 0 after all withdrawals. As all the deposited tokens
                    // have been withdrawn
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
                      // We check that the user balance matches the total deposited amount
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
            method: 'withdrawToken',
            args: [tokenContracts[symbols[0]].options.address, 2000],
            account: accounts[0],
            catch: (error) => {
              // We expect an error to be thrown if the user tries to withdraw
              // more tokens than they have deposited
              errorRaised = true;
              assert.strictEqual(
                error,
                'ERC20ExchangeVault: insufficient balance'
              );
            },
          })
        )
        .then(() => {
          // We check that the error was raised
          assert.ok(errorRaised);
        });
    });
  });

  describe('FUSDTokenHandler', () => {
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
            // For each token adapter, we get the token contract and symbol
            // and we store it in the tokenContracts object
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
              // We get the token price in FUSD
              method: 'tokenPriceInFUSD',
              args: [token.options.address, 1],
              onReturn: (price) => {
                const { decimals, usdOracleValue } = erc20Params[symbol];
                const expectedPrice =
                  usdOracleValue *
                  10 ** (fusdDecimals - decimals - usdValDecimals);
                // We caclulate the expected price in FUSD and check that it matches
                assert.strictEqual(parseInt(price), expectedPrice);
              },
            }))
          )
        );
    });

    it('returns total user collateral worth in FUSD', () => {
      const decimals = 18;
      const depositPerToken = 1000;
      const tokenUsdWorth = symbols.reduce((acc, symbol) => {
        acc[symbol] = randomInt(1, 50) / 10;
        return acc;
      }, {});
      const userDepositsAndLoans = Object.keys(tokenUsdWorth).map((symbol) => ({
        symbol,
        amount: depositPerToken,
        loanAmount: 100,
        account: accounts[1],
      }));
      const tokenContracts = {};
      const erc20Params = mapObject(tokenUsdWorth, (usdWorth) => ({
        decimals,
        usdOracleValue: Math.round(usdWorth * 10 ** usdValDecimals),
      }));

      const totalWorth = Object.values(tokenUsdWorth).reduce(
        (acc, worth) => acc + worth * depositPerToken,
        0
      );

      return setUpUserCollateralAndLoans(
        userDepositsAndLoans,
        tokenContracts,
        erc20Params
      ).then(() =>
        useMethodOn(FUSDTokenSale, {
          method: 'getUserCollateralWorthInFUSD',
          args: [accounts[1]],
          onReturn: (result) => {
            // We get the total user collateral worth in FUSD
            // and check that it matches the expected total worth
            assert.strictEqual(parseInt(result), totalWorth);
          },
        })
      );
    });
  });

  describe('LiquidatingUserAssetsBelowLiquidationThreshold', () => {
    /**
     * Returns the first oracle contract instance from the token sale contract
     */
    const getOracleFromTokenAdapter = () =>
      useMethodOn(FUSDTokenSale, {
        method: 'getTokenAdapterAddresses',
        onReturn: () => {},
      })
        .then((tokenAdapterAddresses) =>
          getDeployedContract(adapterContract, tokenAdapterAddresses[0])
        )
        .then((TokenAdapter) =>
          useMethodOn(TokenAdapter, {
            method: 'getOracle',
            onReturn: () => {},
          })
        )
        .then((oracleAddress) =>
          getDeployedContract(oracleContract, oracleAddress)
        );

    it('returns liquidation threshold', () =>
      useMethodOn(FUSDTokenSale, {
        // We get the liquidation threshold
        method: 'getLiquidationThreshold',
        onReturn: (lt) => {
          // and check that it matches the one we set on deployment
          assert.strictEqual(
            parseInt(lt),
            1000 + liquidationPenalty + annualInterestRate
          );
        },
      }));

    it('returns all debtors', () => {
      const userDepositsAndLoans = generateUserDepositsAndLoans();
      const { userToPayOffDebt, totalUserLoanAmount } =
        getRandomUserAndLoanAmount(userDepositsAndLoans);
      const accountsWithDeposits =
        getAccountsWithDeposits(userDepositsAndLoans);

      return setUpUserCollateralAndLoans(userDepositsAndLoans)
        .then(() =>
          useMethodOn(FUSDToken, {
            // User approves the token sale contract to spend their loan amount
            method: 'approve',
            args: [FUSDTokenSale.options.address, totalUserLoanAmount],
            account: userToPayOffDebt,
          })
        )
        .then(() =>
          useMethodsOn(FUSDTokenSale, [
            {
              // User pays off all debt
              method: 'payOffAllDebt',
              account: userToPayOffDebt,
            },
            {
              // We get an array of all debtors
              method: 'getAllDebtors',
              onReturn: (debtors) => {
                // and check that it matches the accounts with deposits.
                // This array should include all accounts that have deposited,
                // even if they have paid off all debt
                assert.deepStrictEqual(debtors, accountsWithDeposits);
              },
            },
          ])
        );
    });

    it('returns current debtors', () => {
      const userDepositsAndLoans = generateUserDepositsAndLoans();
      const { userToPayOffDebt, totalUserLoanAmount } =
        getRandomUserAndLoanAmount(userDepositsAndLoans);
      const accountsWithDeposits =
        getAccountsWithDeposits(userDepositsAndLoans);

      return setUpUserCollateralAndLoans(userDepositsAndLoans)
        .then(() =>
          useMethodOn(FUSDToken, {
            method: 'approve',
            args: [FUSDTokenSale.options.address, totalUserLoanAmount],
            account: userToPayOffDebt,
          })
        )
        .then(() =>
          useMethodsOn(FUSDTokenSale, [
            {
              // User pays off all debt
              method: 'payOffAllDebt',
              account: userToPayOffDebt,
            },
            {
              method: 'getCurrentDebtors',
              onReturn: (debtors) => {
                // We get an array of current debtors
                // and check that it omits the account that paid off all debt
                assert.deepStrictEqual(
                  debtors,
                  accountsWithDeposits.filter(
                    (account) => account !== userToPayOffDebt
                  )
                );
              },
            },
          ])
        );
    });

    /**
     * Returns an object with user deposits, accounts with deposits and token contracts
     * for a test case where a user's collateral ratio drops below LT
     */
    const getLTDropTestCaseParams = ({
      symbol = 'N/A',
      tokenToFallBelowLT,
      decimals = 18,
      oracleValue = 1,
      depositAmount = 150,
      loanAmount = 100,
    }) => {
      const usdOracleValue = oracleValue * 10 ** usdValDecimals;
      const erc20Params = {
        [symbol]: {
          decimals,
          usdOracleValue,
        },
        [tokenToFallBelowLT]: { decimals, usdOracleValue },
      };
      const userDepositsAndLoans = [
        {
          // In this test we want to simulate a user depositing a token
          // for which the price drops and hence their collateral ratio
          // drops below LT. The user should be included in the debtors below LT
          // array
          symbol: tokenToFallBelowLT,
          amount: depositAmount,
          loanAmount,
          account: accounts[1],
        },
        ...newArray(4, () => ({
          symbol,
          amount: 150,
          loanAmount: 100,
          account: accounts[randomInt(2, 4)],
        })),
      ];
      const accountsWithDeposits =
        getAccountsWithDeposits(userDepositsAndLoans);

      return {
        erc20Params,
        userDepositsAndLoans,
        accountsWithDeposits,
      };
    };

    it('flags user as below LT if collateral worth drops due to oracle value dropping', () => {
      const symbol = 'USDT';

      const { erc20Params, userDepositsAndLoans } = getLTDropTestCaseParams({
        tokenToFallBelowLT: symbol,
      });

      const testCases = [
        {
          tokenUsdRatio: 0.9, // 1 USDT = 0.9 USD
          expectedCR: 135, // Collateral ration 150 * 0.9 / 100 = 135%
          expectedLT: false,
        },
        {
          tokenUsdRatio: 0.8,
          // Liquidation threshold is 120% (100% + 8% intrest rate + 12% liquidation penalty)
          // At this point the user is not below LT
          expectedCR: 120,
          expectedLT: false,
        },
        {
          tokenUsdRatio: 0.7999,
          // If collateral ratio drops below 120% the user is below LT
          expectedCR: 119,
          // And is flagged as below LT
          expectedLT: true,
        },
        {
          tokenUsdRatio: 0.7,
          expectedCR: 105,
          expectedLT: true,
        },
      ];

      let Oracle;

      return setUpUserCollateralAndLoans(
        userDepositsAndLoans.slice(0, 1),
        {}, // tokenContracts reference not needed
        erc20Params
      )
        .then(async () => (Oracle = await getOracleFromTokenAdapter()))
        .then(() =>
          useMethodsOn(FUSDTokenSale, [
            {
              method: 'getCollateralRatio',
              args: [accounts[1]],
              onReturn: (collateralRatio) => {
                // Initially 1 USDT = 1 USD, so collateral ratio is 150%
                assert.strictEqual(parseInt(collateralRatio), 150 * 10);
              },
            },
            {
              method: 'isDebtorBelowLiquidationThreshold',
              args: [accounts[1]],
              onReturn: (isBelowLT) => {
                // Initially the user is not below LT
                assert.ok(!isBelowLT);
              },
            },
          ])
        )
        .then(() =>
          runPromisesInSequence(
            testCases.map(
              ({ tokenUsdRatio, expectedCR, expectedLT }) =>
                () =>
                  useMethodOn(Oracle, {
                    // We update the oracle value to simulate the token price dropping
                    method: 'setValue',
                    args: [
                      `${symbol}/USD`,
                      tokenUsdRatio * 10 ** usdValDecimals,
                      timeInSecs(),
                    ],
                    account: accounts[0],
                  }).then(() =>
                    useMethodsOn(FUSDTokenSale, [
                      {
                        // We get the user collateral ratio
                        method: 'getCollateralRatio',
                        args: [accounts[1]],
                        onReturn: (collateralRatio) => {
                          assert.strictEqual(
                            parseInt(collateralRatio),
                            expectedCR * 10
                          );
                        },
                      },
                      {
                        // We check if the user is below LT
                        method: 'isDebtorBelowLiquidationThreshold',
                        args: [accounts[1]],
                        onReturn: (isBelowLT) => {
                          assert.strictEqual(isBelowLT, expectedLT);
                        },
                      },
                    ])
                  )
            )
          )
        );
    });

    it('returns debtors below liquidation threshold', () => {
      const symbol = 'USDT';
      const tokenToFallBelowLT = 'USDC';
      const { erc20Params, userDepositsAndLoans, accountsWithDeposits } =
        getLTDropTestCaseParams({ symbol, tokenToFallBelowLT });

      let Oracle;

      return setUpUserCollateralAndLoans(
        userDepositsAndLoans,
        {}, // tokenContracts reference not needed
        erc20Params
      )
        .then(async () => (Oracle = await getOracleFromTokenAdapter()))
        .then(() =>
          useMethodOn(Oracle, {
            // We update the oracle value to simulate the token price dropping
            method: 'setValue',
            args: [
              `${tokenToFallBelowLT}/USD`,
              0.5 * 10 ** usdValDecimals,
              timeInSecs(),
            ],
            account: accounts[0],
          }).then(() =>
            useMethodsOn(FUSDTokenSale, [
              {
                // We get an array of debtors below LT
                method: 'getDebtorsBelowLiquidationThreshold',
                onReturn: (debtors) => {
                  // which should include the account that deposited the token
                  // for which the price dropped and hence their collateral ratio
                  // dropped below LT
                  assert.deepStrictEqual(debtors, [accounts[1]]);
                },
              },
              {
                method: 'getAllDebtors',
                onReturn: (debtors) => {
                  // We also get an array of all debtors
                  // and check that other accounts are included in it
                  assert.deepStrictEqual(debtors, accountsWithDeposits);
                },
              },
            ])
          )
        );
    });

    describe('Liquidation process', () => {
      const symbol = 'USDT';
      const tokenToFallBelowLT = 'USDC';
      const loanAmount = 100;
      const depositAmount = 150;
      let tokenContracts = {};

      beforeEach(() => {
        // In these tests we want to simulate a user depositing a token
        // for which the price drops and hence their collateral ratio
        // drops below LT. The user should be included in the debtors below LT
        // array
        const { erc20Params, userDepositsAndLoans } = getLTDropTestCaseParams({
          symbol,
          tokenToFallBelowLT,
          loanAmount,
          depositAmount,
        });

        let Oracle;
        tokenContracts = {};

        return setUpUserCollateralAndLoans(
          userDepositsAndLoans,
          tokenContracts,
          erc20Params
        )
          .then(async () => (Oracle = await getOracleFromTokenAdapter()))
          .then(() =>
            useMethodOn(Oracle, {
              // We update the oracle value to simulate the token price dropping
              method: 'setValue',
              args: [
                `${tokenToFallBelowLT}/USD`,
                0.5 * 10 ** usdValDecimals,
                timeInSecs(),
              ],
              account: accounts[0],
            })
          );
      });

      it('emits an event on liquidation', () =>
        useMethodOn(FUSDTokenSale, {
          method: 'liquidateAllDebtorsBelowLiquidationThreshold',
          account: accounts[0],
        }).then(async () => {
          const [{ data, event }] = await getContractEvents(FUSDTokenSale);
          const { user } = data;
          // We check that the event is emitted with the correct user
          assert.strictEqual(event, 'LiquidatedUser');
          assert.strictEqual(user, accounts[1]);
        }));

      it('erases user debt on liquidation', () =>
        useMethodsOn(FUSDTokenSale, [
          {
            method: 'liquidateAllDebtorsBelowLiquidationThreshold',
            account: accounts[0],
          },
          {
            method: 'getTotalDebt',
            args: [accounts[1]],
            onReturn: (totalDebt) => {
              // We check that the user debt has been erased
              assert.strictEqual(parseInt(totalDebt), 0);
            },
          },
        ]));

      it('liquidates user collateral', () =>
        useMethodsOn(FUSDTokenSale, [
          {
            method: 'liquidateAllDebtorsBelowLiquidationThreshold',
            account: accounts[0],
          },
          {
            method: 'getUserTokenBalances',
            args: [accounts[1]],
            onReturn: (result) => {
              const formattedBalances = formatTokenBalances(
                result[0],
                result[1]
              );

              // We check that the user collateral has been liquidated
              assert.strictEqual(formattedBalances[tokenToFallBelowLT], 0);
            },
          },
        ]));

      it('user collateral is sent to a withdrawable address', () =>
        useMethodsOn(FUSDTokenSale, [
          {
            method: 'liquidateAllDebtorsBelowLiquidationThreshold',
            account: accounts[0],
          },
          {
            method: 'getERC20WithdrawableAddress',
            onReturn: () => {},
          },
        ]).then((withdrawableAddress) =>
          useMethodOn(tokenContracts[tokenToFallBelowLT], {
            method: 'balanceOf',
            args: [withdrawableAddress],
            onReturn: (balance) => {
              // We check that the user collateral has been sent to the withdrawable address
              assert.strictEqual(parseInt(balance), depositAmount);
            },
          })
        ));
    });
  });

  describe('wTLOS', () => {
    let wTLOS;

    beforeEach(async () => {
      wTLOS = await deploy(
        getOldVersionContract('test/WTLOS.sol'),
        [],
        accounts[0]
      );
    });

    const setUpWTLOSTokenAdapter = () =>
      useMethodOn(DIAOracleV2, {
        // We set the value for the token symbol we are using in the tests
        method: 'setValue',
        args: ['TLOS/USD', 1 * 10 ** usdValDecimals, timeInSecs()],
        account: accounts[0],
      })
        .then(() =>
          // We deploy the token adapter contract with the oracle and token addresses.
          // The oracle must have a value for the token symbol we are using in the tests
          deploy(
            contracts['DIAOracleV2wTLOSAdapter.sol'].DIAOracleV2wTLOSAdapter,
            [DIAOracleV2.options.address, wTLOS.options.address],
            accounts[0]
          )
        )

        .then((tokenAdapter) =>
          useMethodOn(FUSDTokenSale, {
            method: 'addTokenAdapter',
            args: [tokenAdapter.options.address],
            account: accounts[0],
          })
        );

    it('deploys successfully', () => {
      assert.ok(wTLOS.options.address);
    });

    it('accepts TLOS deposits', () => {
      const depositAmount = randomInt(1000, 10000);

      return useMethodsOn(wTLOS, [
        {
          // User deposits TLOS to receive wTLOS
          method: 'deposit',
          account: accounts[0],
          value: depositAmount,
        },
        {
          // We check that the user balance matches the deposit amount
          method: 'balanceOf',
          args: [accounts[0]],
          onReturn: (balance) => {
            assert.strictEqual(parseInt(balance), depositAmount);
          },
        },
      ]);
    });

    it('can be sent as deposit to FUSDTokenSale', () => {
      const depositAmount = randomInt(1000, 10000);

      return setUpWTLOSTokenAdapter()
        .then(() =>
          useMethodsOn(wTLOS, [
            {
              // User deposits TLOS to receive wTLOS
              method: 'deposit',
              account: accounts[0],
              value: depositAmount,
            },
            {
              // And approves the token sale contract to spend their wTLOS
              method: 'approve',
              args: [FUSDTokenSale.options.address, depositAmount],
              account: accounts[0],
            },
          ])
        )
        .then(() =>
          useMethodsOn(FUSDTokenSale, [
            {
              // User deposits wTLOS in the token sale contract
              method: 'depositToken',
              args: [wTLOS.options.address, depositAmount],
              account: accounts[0],
            },
            {
              // We check that the user balance matches the deposit amount
              method: 'getUserTokenBalances',
              args: [accounts[0]],
              onReturn: (result) => {
                const formattedBalances = formatTokenBalances(
                  result[0],
                  result[1]
                );

                assert.strictEqual(formattedBalances.WTLOS, depositAmount);
              },
            },
          ])
        );
    });
  });
});
