const path = require('path');
const fs = require('fs');

const FILE_VERSION_TO_COMPILER = {
  '0.4.18': '0.4.26+commit.4563c3fc',
};

const DEVELOPMENT_VERSION = '0.8.20';

function getAllFilesInFolder(folderPath) {
  const files = [];

  function traverseFolder(currentPath) {
    const contents = fs.readdirSync(currentPath);

    for (const item of contents) {
      const itemPath = path.join(currentPath, item);
      const itemStat = fs.statSync(itemPath);

      if (itemStat.isFile()) {
        files.push(itemPath);
      } else if (itemStat.isDirectory()) {
        traverseFolder(itemPath);
      }
    }
  }

  traverseFolder(folderPath);

  return files;
}

function getSolidityVersion(source) {
  const solidityVersion = source.match(/pragma solidity (.+?);/);

  if (!solidityVersion) {
    throw new Error('Solidity version not found');
  }

  return solidityVersion[1];
}

function solidityVersionCompare(a, b) {
  const aParts = a.split('.');
  const bParts = b.split('.');

  for (let i = 0; i < aParts.length; i++) {
    if (Number(aParts[i]) > Number(bParts[i])) {
      return 1;
    } else if (Number(aParts[i]) < Number(bParts[i])) {
      return -1;
    }
  }

  return 0;
}

function solidityVersionEqual(a, b) {
  return solidityVersionCompare(a, b) === 0;
}

function createInputData(additionalData) {
  return {
    language: 'Solidity',
    sources: {},
    settings: {
      outputSelection: {
        '*': {
          '*': ['*'],
        },
      },
    },
    ...additionalData,
  };
}

function formatCompileErrors(compiledInfo) {
  return compiledInfo.errors.map(({ formattedMessage }) => formattedMessage);
}

function getAllContractFiles(contractsPath, fileVersion = undefined) {
  return getAllFilesInFolder(contractsPath).reduce((acc, file) => {
    const fileName = path.relative(contractsPath, file).replace(/\\/g, '/');
    const source = fs.readFileSync(file, 'utf8');
    const solidityVersion = getSolidityVersion(source);

    if (!fileVersion || solidityVersionEqual(solidityVersion, fileVersion)) {
      acc[fileName] = {
        content: source,
      };
    }

    return acc;
  }, {});
}

function compileContracts(compiler, input) {
  const compiledInfo = JSON.parse(compiler.compile(JSON.stringify(input)));

  if (compiledInfo.errors) {
    console.error(formatCompileErrors(compiledInfo));
  }

  return compiledInfo.contracts;
}

module.exports = {
  FILE_VERSION_TO_COMPILER,
  DEVELOPMENT_VERSION,
  solidityVersionEqual,
  createInputData,
  getAllContractFiles,
  compileContracts,
};
