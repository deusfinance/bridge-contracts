var bridge = artifacts.require('./DeusBridge.sol')
var muon = artifacts.require('./MuonV01.sol')
var app = artifacts.require('./SampleApp.sol')

function parseArgv(){
	let args = process.argv.slice(2);
	let params = args.filter(arg => arg.startsWith('--'))
	let result = {}
	params.map(p => {
		let [key, value] = p.split('=');
		result[key.slice(2)] = value === undefined ? true : value
	})
	return result;
}

module.exports = function (deployer) {
	let params = parseArgv()
	let mintable = params['mintable'] || 'false'

	mintable = mintable === 'true' || mintable === true || mintable == 1;

	deployer.deploy(muon).then(() => {
		return deployer.deploy(bridge, muon.address, mintable)
	})
}
