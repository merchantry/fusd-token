const ProxyOFTV2 = artifacts.require('ProxyOFTV2');

const FUSDTokenTestnetAddress = '0x0A76f3773A62Ab84B63098C4b39D8faB93fFc5D4';
const sharedDecimals = 18;
const endpointAddress = '0x83c73Da98cf733B03315aFa8758834b36a195b87';

module.exports = function (deployer) {
  return deployer.deploy(
    ProxyOFTV2,
    FUSDTokenTestnetAddress,
    sharedDecimals,
    endpointAddress
  );
};
