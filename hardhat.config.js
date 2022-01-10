const path = require('path');
const envPath = path.join(__dirname, '.env');
require('dotenv').config({ path: envPath });

require('hardhat-deploy');
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
// require("@nomiclabs/hardhat-vyper");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
	const accounts = await ethers.getSigners();

	for (const account of accounts) {
		console.log(account.address);
	}
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	defaultNetwork: "localhost",
	networks: {
		localhost: {
			url: 'http://127.0.0.1:8545',
			accounts: [
				process.env.DEPLOYER_PRIVATE_KEY,
			],
		},

		rinkeby: {
			url: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
			accounts: [
				process.env.DEPLOYER_PRIVATE_KEY,
			],
			chainId: 4,
			gas: "auto",
			gasPrice: 3100000000,
			gasMultiplier: 1.2
		},
		metis: {
			url: "https://andromeda.metis.io/?owner=1088",
			accounts: [
				process.env.DEPLOYER_PRIVATE_KEY,
			],
			chainId: 1088,
			gas: "auto",
			gasPrice: 23e9,	// 23 Gwei
			gasMultiplier: 1.2
		},
		arbitrum: {
			url: "https://arb1.arbitrum.io/rpc",
			accounts: [
				process.env.DEPLOYER_PRIVATE_KEY,
			],
			chainId: 42161,
			gas: "auto",
			gasPrice: 'auto',
			gasMultiplier: 1.2
		}
	},
	solidity: {
		compilers: [
			{
				version: "0.5.17",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			},
			{
				version: "0.6.11",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			},
			{
				version: "0.6.6",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			},
			{
				version: "0.7.6",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			},
			{
				version: "0.8.0",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			},
			{
				version: "0.8.4",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			},
			{
				version: "0.8.6",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			},
			{
				version: "0.8.7",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			},
			{
				version: "0.8.9",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			},
			{
				version: "0.8.10",
				settings: {
					optimizer: {
						enabled: true,
						runs: 100000
					}
				}
			}
		],
	},
	paths: {
		sources: "./contracts",
		tests: "./test",
		cache: "./cache",
		artifacts: "./artifacts"
	},
	mocha: {
		timeout: 360000
	},
	etherscan: {
		apiKey: process.env.ETHERSCAN_API_KEY, // ETH Mainnet
		// apiKey: process.env.FANTOM_API_KEY, // FANTOM Mainnet
		// apiKey: process.env.POLYGON_API_KEY, // ETH Mainnet
		// apiKey: process.env.HECO_API_KEY, // HECO Mainnet
		// apiKey: process.env.BSCSCAN_API_KEY // BSC
		// apiKey: process.env.ARBISCAN_API_KEY, // Arbitrum
	},
	contractSizer: {

		alphaSort: true,
		runOnCompile: true,
		disambiguatePaths: false,
	},
	vyper: {
		version: "0.2.12"
	},
};

