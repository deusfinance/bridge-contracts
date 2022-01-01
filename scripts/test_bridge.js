// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const { deploy, verifyAll } = require('./helpers/deploy_contract');
const sleep = require('./helpers/sleep');
const { impersonate, setBalance } = require('./helpers/modify_chain');
const { assert } = require('./helpers/testing');

async function main() {

  const deployer = process.env.DEPLOYER_PUBLIC_KEY;
  await setBalance(deployer)

  const muonAddress = '0xE4F8d9A30936a6F8b17a73dC6fEb51a3BBABD51A';
  const mintable = true;
  const deiAddress = '0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3';
  const minReqSigs = 1;
  const bridgeReserve = "5000000000000000000000000";

  const deusBridge = await deploy({
    deployer: deployer,
    contractName: 'DeusBridge',
    constructorArguments: [
      minReqSigs,
      bridgeReserve,
      "7",
      muonAddress,
      deiAddress,
      mintable
    ]
  });

  const sideBridge = await deploy({
    deployer: deployer,
    contractName: 'DeusBridge',
    constructorArguments: [
      minReqSigs,
      bridgeReserve,
      "7",
      muonAddress,
      deiAddress,
      mintable
    ]
  });

  const token = await deploy({
    deployer: deployer,
    contractName: 'ERT',
    constructorArguments: []
  })

  console.log(" - config bridges")

  await deusBridge.setNetworkID(1)
  await deusBridge.setSideContract(2, await sideBridge.address);
  await deusBridge.setToken(1, token.address);

  await sideBridge.setNetworkID(2);

  console.log(" - mint and approve token")
  await token.mint(deployer, 300);
  await token.approve(deusBridge.address, 100);

  console.log(" - deposit token")
  await deusBridge['deposit(uint256,uint256,uint256)'](100, 2, 1);

  assert(await token.balanceOf(deployer) == 200, "Deplosit didn't burn token");



}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
