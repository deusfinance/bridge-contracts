const hre = require("hardhat");

var deployedContracts = [];

module.exports = {
    deploy: async ({ deployer, contractName, constructorArguments }) => {
        const contractInstance = await hre.ethers.getContractFactory(contractName, await hre.ethers.getSigner(deployer));

        const contract = await contractInstance.deploy(...constructorArguments);
        await contract.deployed();
        console.log(contractName, "deployed to:", contract.address);

        deployedContracts.push({
            address: contract.address,
            constructorArguments: constructorArguments
        })

        return contract
    },
    verifyAll: async () => {
        console.log(deployedContracts);
        for(let i = 0;i < deployedContracts.length;i++){
            let contract = deployedContracts[i];
            console.log("verifing", contract['address']);
            await hre.run('verify:verify', contract);
        }
        deployedContracts = [];
    }
}
