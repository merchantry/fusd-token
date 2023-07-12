const Web3 = require('web3');
const contracts = require('../compile');
const { useMethodOn } = require('../utils/contracts');
const { schedule, everyMinute } = require('../utils/cronJob');

const PROVIDER = process.argv[2] || undefined;
const PRIVATE_KEY = process.argv[3] || undefined;
const SALE_CONTRACT_ADDRESS = process.argv[4] || undefined;

if (!PROVIDER) {
  throw new Error('No provider specified');
}

if (!PRIVATE_KEY) {
  throw new Error('No private key specified');
}

if (!SALE_CONTRACT_ADDRESS) {
  throw new Error('No sale contract address specified');
}

const web3Provider = new Web3.providers.HttpProvider(PROVIDER);
const web3 = new Web3(web3Provider);

const saleContract = contracts['FUSDTokenSale.sol'].FUSDTokenSale;

const account = web3.eth.accounts.privateKeyToAccount('0x' + PRIVATE_KEY);
const FUSDTokenSale = new web3.eth.Contract(
  saleContract.abi,
  SALE_CONTRACT_ADDRESS
);

web3.eth.accounts.wallet.add(account);
web3.eth.defaultAccount = account.address;

schedule(everyMinute, async () => {
  const debtorsBelowLT = await useMethodOn(FUSDTokenSale, {
    method: 'getDebtorsBelowLiquidationThreshold',
    onReturn: () => {},
  });

  // eslint-disable-next-line no-console
  console.log('Debtors below liquidation threshold: ', debtorsBelowLT);

  if (debtorsBelowLT.length === 0) return;

  await useMethodOn(FUSDTokenSale, {
    method: 'liquidateAllDebtorsBelowLiquidationThreshold',
  });
});
