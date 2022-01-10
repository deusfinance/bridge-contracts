// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const { deploy, verifyAll } = require('./helpers/deploy_contract');
const sleep = require('./helpers/sleep');

async function main() {
  const deployer = process.env.DEPLOYER_PUBLIC_KEY

  const muonAddress = '0x08654c8f419b29840a2ec6522ad2ed99ab850ee1';
  const mintable = true;
  const deiAddress = '0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3';
  const minReqSigs = 1;
  const bridgeReserve = "5000000000000000000000000";

  await deploy({
    deployer: deployer,
    contractName: 'DeusBridge',
    constructorArguments: [minReqSigs,
      bridgeReserve,
      "7",
      muonAddress,
      deiAddress,
      mintable
    ]
  });

  await sleep(30000);

  await verifyAll();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

