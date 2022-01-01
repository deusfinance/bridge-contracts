const hre = require("hardhat");

async function setBalance(account, balance = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff") {
    await hre.network.provider.request({
        method: "hardhat_setBalance",
        params: [
            account,
            balance,
        ]
    });
}

async function impersonate(account) {
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [account],
    });

    await setBalance(account);

    return await hre.ethers.getSigner(account)
}

async function getBalanceOf(tokenAddress, address, removeDecimals = false) {
    const ERC20 = await hre.ethers.getContractFactory("ERC20");
    const token = ERC20.attach(tokenAddress);
    let balance = await token.balanceOf(address)
    if (removeDecimals) {
        balance /= 10 ** (await token.decimals())
    }
    return balance
}

async function transfer(tokenAddress, fromAddress, toAddress, amount) {
    const signer = await impersonate(fromAddress)
    const ERC20 = await hre.ethers.getContractFactory("ERC20", signer);
    const token = ERC20.attach(tokenAddress);
    console.log(await getBalanceOf(tokenAddress, fromAddress, true), amount / BigInt(1e18))
    // todo: does not work, throws 'ERC20: transfer amount exceeds balance'
    await token.transfer(toAddress, amount)
    throw 'ha'
}

module.exports = {
    impersonate,
    transfer,
    getBalanceOf,
    setBalance,
}