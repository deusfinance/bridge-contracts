const hre = require("hardhat");

module.exports = async (ms) => {
    console.log("sleeping for", ms / 1000, "seconds");
    await new Promise((resolve) => setTimeout(resolve, ms));
}