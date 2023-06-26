const path = require('path');
const fs = require('fs');

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

module.exports = {
  getAllFilesInFolder,
};
