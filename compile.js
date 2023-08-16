const path = require('path');
const solc = require('solc');
const {
  DEVELOPMENT_VERSION,
  createInputData,
  getAllContractFiles,
  compileContracts,
} = require('./utils/compile');

module.exports = compileContracts(
  solc,
  createInputData({
    sources: getAllContractFiles(
      path.join(__dirname, 'contracts'),
      DEVELOPMENT_VERSION
    ),
  })
);
