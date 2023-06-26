const path = require('path');
const fs = require('fs');
const solc = require('solc');
const paths = require('./contracts');
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

paths
  .flatMap((file) => {
    const pathToFile = path.resolve(__dirname, 'contracts', file);
    const itemStat = fs.statSync(pathToFile);
    if (itemStat.isFile()) return pathToFile;
    return getAllFilesInFolder(pathToFile);
  })
  .forEach((file) => {
    const fileName = file.split('contracts\\').pop().replace(/\\/g, '/');
    const source = fs.readFileSync(file, 'utf8');

    input.sources[fileName] = {
      content: source,
    };
  });

const compiledInfo = JSON.parse(solc.compile(JSON.stringify(input)));
if (compiledInfo.errors) console.error(formatCompileErrors(compiledInfo));

module.exports = compiledInfo.contracts;
