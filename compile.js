const path = require('path');
const fs = require('fs');
const solc = require('solc');
const { formatCompileErrors } = require('./utils/debug');
const { getAllFilesInFolder } = require('./utils/compile');

const input = {
  language: 'Solidity',
  sources: {},
  settings: {
    outputSelection: {
      '*': {
        '*': ['*'],
      },
    },
  },
};

getAllFilesInFolder(path.join(__dirname, 'contracts')).forEach((file) => {
  const fileName = file.split('contracts\\').pop().replace(/\\/g, '/');
  const source = fs.readFileSync(file, 'utf8');

  input.sources[fileName] = {
    content: source,
  };
});

const compiledInfo = JSON.parse(solc.compile(JSON.stringify(input)));
if (compiledInfo.errors) console.error(formatCompileErrors(compiledInfo));

module.exports = compiledInfo.contracts;
