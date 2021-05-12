var bridge = artifacts.require('./DeusBridge.sol')

module.exports = function (deployer) {
  deployer.deploy(bridge, 2)
}
