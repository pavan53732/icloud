const hre = require("hardhat");
const prompt = require("prompt-sync")({sigint: true});

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    const profitReceiver = prompt("Enter your wallet address to receive profits: ").trim();
    const providerAddr = "0xa97684ead0e402dc232d5a977953df7ecbab3cdb"; // Aave v3 Polygon Provider

    console.log("Deploying contract with account:", deployer.address);
    console.log("Profit receiver will be:", profitReceiver);

    const ContractFactory = await hre.ethers.getContractFactory("FlashAaveArbBot");
    const contract = await ContractFactory.deploy(profitReceiver, providerAddr);

    await contract.deployed();
    console.log("Contract deployed to:", contract.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Deployment failed:", error);
        process.exit(1);
    });