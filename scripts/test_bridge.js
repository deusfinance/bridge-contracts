// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const { deploy } = require('./helpers/deploy_contract');
const { setBalance } = require('./helpers/modify_chain');
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
  assert(await deusBridge.network() == 1, "setNetowrkID does not work");

  await deusBridge.setSideContract(2, await sideBridge.address);
  assert(await deusBridge.sideContracts(2) == await sideBridge.address, "setSideContract does not work");

  await deusBridge.setToken(1, await token.address);
  assert(await deusBridge.tokens(1) == await token.address, "setToken does not work");

  await sideBridge.setNetworkID(2);

  console.log(" - mint and approve token")
  await token.mint(deployer, 1000e6);
  await token.mint(deusBridge.address, 10e6);
  await token.approve(deusBridge.address, 1000e6);

  console.log(" - deposit token")

  const checkTxId = async (user, toChain, i) => {
    let a = (await deusBridge.getUserTxs(user, toChain))
    let b = await deusBridge.lastTxId()
    assert(a[i].eq(b), "Transaction is not added to user transactions");
  }

  let fee = 0.01e6;
  await deusBridge.setFee(1, fee);
  assert(await deusBridge.fee(1) == fee, "setFee does not work");

  await deusBridge['deposit(uint256,uint256,uint256)'](100e6, 2, 1);
  assert(await token.balanceOf(deployer) == 900e6, "Deplosit didn't burn token");
  await checkTxId(deployer, 2, 0);

  await deusBridge['deposit(uint256,uint256,uint256,uint256)'](100e6, 2, 1, 0);
  assert(await token.balanceOf(deployer) == 800e6, "Deplosit didn't burn token");
  await checkTxId(deployer, 2, 1);

  const account = "0x0000000000000000000000000000000000000001"
  await deusBridge['depositFor(address,uint256,uint256,uint256)'](account, 100e6, 2, 1);
  assert(await token.balanceOf(deployer) == 700e6, "Deplosit didn't burn token");
  await checkTxId(account, 2, 0);

  await deusBridge['depositFor(address,uint256,uint256,uint256,uint256)'](account, 200e6, 2, 1, 0);
  assert(await token.balanceOf(deployer) == 500e6, "Deplosit didn't burn token");
  await checkTxId(account, 2, 1);

  assert((await deusBridge.getTransaction(4))['amount'] == 200e6 * (1e6 - fee) / 1e6, "getTransaction return's wrong transaction");

  const dei = await (await hre.ethers.getContractFactory('ERT')).attach(deiAddress);
  let collatDollarBalance = (await deusBridge.bridgeReserve()).mul(await dei.global_collateral_ratio()) / 1e6
  assert(await deusBridge.collatDollarBalance(0) == collatDollarBalance, "collatDollarBalance return's wrong value");


  assert(await deusBridge.getExecutingChainID() == (await hre.ethers.provider.getNetwork()).chainId, "getExecutingChainID return's wrong chian id");

  /* ========== RESTRICTED FUNCTIONS ========== */

  await deusBridge.setBridgeReserve(bridgeReserve + 1);
  assert(await deusBridge.bridgeReserve() == bridgeReserve + 1, "setBridgeReserve does not work");


  await deusBridge.setDeiAddress(account);
  assert(await deusBridge.deiAddress() == account, "setDeiAddress does not work");

  await deusBridge.setMinReqSigs(5);
  assert(await deusBridge.minReqSigs() == 5, "setMinReqSigs does not work");

  await deusBridge.setMintable(false);
  assert(await deusBridge.mintable() == false, "setMintable does not work");

  await deusBridge.setEthAppId(72);
  assert(await deusBridge.ETH_APP_ID() == 72, "setEthAppId does not work");

  await deusBridge.setMuonContract(account);
  assert(await deusBridge.muonContract() == account, "setMuonConract does not work");

  await deusBridge.pause();
  assert(await deusBridge.paused() == true, "puase does not work");

  await deusBridge.unpase();
  assert(await deusBridge.paused() == false, "unpuase does not work");

  let balance = await token.balanceOf(account);
  await deusBridge.withdrawFee(1, account);
  assert(await deusBridge.collectedFee(1) == 0, "withdrawFee does not work currectly");
  assert(balance.lt(await token.balanceOf(account)), "withdrawFee does not mint token");

  balance = await hre.ethers.provider.getBalance(deployer);
  await setBalance(deusBridge.address)
  await deusBridge.emergencyWithdrawETH(deployer, BigInt(10e18));
  assert(balance.lt(await hre.ethers.provider.getBalance(deployer)), "emergencyWithdrawETH does not work");

  balance = await token.balanceOf(account);
  await deusBridge.emergencyWithdrawERC20Tokens(token.address, account, BigInt(5e6));
  assert(balance.lt(await token.balanceOf(account)), "emergencyWithdrawERC20Tokens does not work");

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
