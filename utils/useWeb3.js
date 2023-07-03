const ganache = require('ganache');
const Web3 = require('web3');
const web3 = new Web3(
  ganache.provider({
    gasLimit: 1000000000000,
    logging: {
      logger: {
        log: () => {},
      },
    },
  })
);

const getContractName = (evm) => evm.assembly.match(/\w+(?=\.sol)/)[0];

const deploy = async ({ abi, evm, bytecode }, args, account) => {
  const contract = await new web3.eth.Contract(abi)
    .deploy({
      data: evm ? evm.bytecode.object : bytecode,
      arguments: args,
    })
    .send({
      from: account,
      gas: '1000000000',
    });

  contract.options.name = getContractName(evm);
  return contract;
};

const getDeployedContract = ({ abi, evm }, address) => {
  const contract = new web3.eth.Contract(abi, address);
  contract.options.name = getContractName(evm);
  return contract;
};

const getAccounts = () => web3.eth.getAccounts();

module.exports = {
  deploy,
  getDeployedContract,
  getAccounts,
};
