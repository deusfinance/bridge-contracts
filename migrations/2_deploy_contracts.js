var bridge = artifacts.require('./DeusBridge.sol')
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

		let mintable = params['mintable'] || 'true'
		mintable = mintable === 'true' || mintable === true || mintable == 1;
		let minReqSigs = 1
		let fee = 0
		let bridgeReserve = "10000000000000000000000000"

		if(!params['muonAddress']){
			throw {message: "muonAddress required."}
		}

		let deployedBridge = await deployer.deploy(bridge, params['muonAddress'], mintable, minReqSigs, fee, bridgeReserve)
		if(params['dea']){
			let deployedDea = await deployer.deploy(deaToken)
		}

	})
}
