const solc = require('solc');
const path = require('path');
const {
  createInputData,
  FILE_VERSION_TO_COMPILER,
  getAllContractFiles,
  compileContracts,
} = require('./compile');

function getRemoteVersionCompiler(version) {
  return new Promise((resolve) => {
    solc.loadRemoteVersion(`v${version}`, (err, solcSnapshot) => {
      if (err)
        throw new Error(`Error fetching solc version ${version}: ${err}`);

      resolve(solcSnapshot);
    });
  });
}

async function getContracts() {
  return Object.entries(FILE_VERSION_TO_COMPILER).reduce(
    async (acc, [fileVersion, compilerVersion]) => {
      const contracts = await compileContracts(
        await getRemoteVersionCompiler(compilerVersion),
        createInputData({
          sources: getAllContractFiles(
            path.resolve(__dirname, '..', 'contracts'),
            fileVersion
          ),
        })
      );

      return {
        ...(await acc),
        ...contracts,
      };
    },
    {}
  );
}

class OldVersionCompiler {
  constructor() {
    this.contracts = null;
  }

  async get() {
    if (!this.contracts) {
      this.contracts = await getContracts();
    }

    return this.contracts;
  }
}

module.exports = new OldVersionCompiler();
