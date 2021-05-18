var bridge = artifacts.require('./DeusBridge.sol')
var muon = artifacts.require('./MuonV01.sol')
var app = artifacts.require('./SampleApp.sol')

module.exports = function (deployer) {
  deployer.deploy(muon).then(() => {
  	return deployer.deploy(bridge, 2, muon.address)
  })
}
