var bridge = artifacts.require('./DeusBridge.sol')
var muon = artifacts.require('./MuonV01.sol')
var deaToken = artifacts.require('./DEAToken.sol')

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
	deployer.then(async () => {

		let params = parseArgv()
		let mintable = params['mintable'] || 'false'

		mintable = mintable === 'true' || mintable === true || mintable == 1;

		let deployedMuon = await deployer.deploy(muon);
		let deployedBridge = await deployer.deploy(bridge, deployedMuon.address, mintable)
		if(params['dea']){
			let deployedDea = await deployer.deploy(deaToken)
		}

	})
}
