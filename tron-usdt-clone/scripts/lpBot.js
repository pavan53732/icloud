const TronWeb = require('tronweb');
const axios = require('axios');
const cron = require('node-cron');

/**
 * Liquidity Bot - Simulates realistic DEX activity and maintains price peg
 * Runs every 60 seconds to emit realistic swap/liquidity events
 */

// Configuration
const config = {
    fullNode: process.env.TRON_FULL_NODE || 'https://api.trongrid.io',
    solidityNode: process.env.TRON_SOLIDITY_NODE || 'https://api.trongrid.io',
    eventServer: process.env.TRON_EVENT_SERVER || 'https://api.trongrid.io',
    privateKey: process.env.BOT_PRIVATE_KEY || '',
    
    // Contract addresses
    usdtCloneAddress: process.env.USDT_CLONE_ADDRESS || '',
    fakePairAddress: process.env.FAKE_PAIR_ADDRESS || '',
    realUsdtAddress: 'TR7NHqjeKQxGTCi8q8ZQojndr2EbSWRiff',
    
    // Bot parameters
    minInterval: 45, // seconds
    maxInterval: 75, // seconds
    priceDeviationThreshold: 0.001, // 0.1%
    volumeMultiplier: 1.2,
    
    // Price oracle
    priceApiUrl: 'https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=usd',
    trxPriceUrl: 'https://api.coingecko.com/api/v3/simple/price?ids=tron&vs_currencies=usd'
};

// Initialize TronWeb
const tronWeb = new TronWeb({
    fullHost: config.fullNode,
    privateKey: config.privateKey
});

// Contract instances
let usdtClone, fakePair;

// Bot state
let botState = {
    isRunning: false,
    lastPrice: 1.0,
    lastTrxPrice: 0.06,
    totalVolume24h: 0,
    swapCount: 0,
    liquidityEvents: 0,
    lastActivity: Date.now()
};

/**
 * Initialize bot
 */
async function initializeBot() {
    try {
        console.log('🤖 Initializing Liquidity Bot...');
        
        // Load contracts
        usdtClone = await tronWeb.contract().at(config.usdtCloneAddress);
        fakePair = await tronWeb.contract().at(config.fakePairAddress);
        
        // Verify contracts
        const pairToken0 = await fakePair.token0().call();
        const pairToken1 = await fakePair.token1().call();
        console.log(`✅ Pair initialized: ${pairToken0} / ${pairToken1}`);
        
        // Get initial reserves
        const reserves = await fakePair.getReserves().call();
        console.log(`📊 Initial reserves: ${reserves._reserve0} / ${reserves._reserve1}`);
        
        // Start monitoring real USDT
        await monitorRealUSDT();
        
        botState.isRunning = true;
        console.log('✅ Bot initialized successfully');
        
    } catch (error) {
        console.error('❌ Initialization error:', error);
        process.exit(1);
    }
}

/**
 * Monitor real USDT price and activity
 */
async function monitorRealUSDT() {
    try {
        // Get current USDT price
        const priceResponse = await axios.get(config.priceApiUrl);
        const usdtPrice = priceResponse.data.tether.usd;
        botState.lastPrice = usdtPrice;
        
        // Get TRX price
        const trxResponse = await axios.get(config.trxPriceUrl);
        const trxPrice = trxResponse.data.tron.usd;
        botState.lastTrxPrice = trxPrice;
        
        console.log(`💵 USDT Price: $${usdtPrice} | TRX Price: $${trxPrice}`);
        
        // Monitor real USDT events (simplified - in production use WebSocket)
        // This would connect to real USDT contract events
        
    } catch (error) {
        console.error('❌ Price monitoring error:', error);
    }
}

/**
 * Generate realistic swap activity
 */
async function generateSwapActivity() {
    try {
        const reserves = await fakePair.getReserves().call();
        const reserve0 = parseInt(reserves._reserve0);
        const reserve1 = parseInt(reserves._reserve1);
        
        // Calculate current price
        const currentPrice = reserve0 / reserve1 / (10 ** 6); // Adjust for decimals
        const targetPrice = botState.lastPrice / botState.lastTrxPrice;
        
        // Determine swap direction based on price deviation
        const priceDeviation = Math.abs(currentPrice - targetPrice) / targetPrice;
        
        if (priceDeviation > config.priceDeviationThreshold) {
            // Need to rebalance
            await performArbitrageSwap(currentPrice, targetPrice, reserve0, reserve1);
        } else {
            // Normal organic swap
            await performOrganicSwap(reserve0, reserve1);
        }
        
        botState.swapCount++;
        
    } catch (error) {
        console.error('❌ Swap generation error:', error);
    }
}

/**
 * Perform arbitrage swap to maintain peg
 */
async function performArbitrageSwap(currentPrice, targetPrice, reserve0, reserve1) {
    const swapSize = calculateArbitrageSize(currentPrice, targetPrice, reserve0, reserve1);
    
    if (currentPrice > targetPrice) {
        // USDT is overpriced, sell USDT for TRX
        const amount0In = swapSize;
        const amount1Out = getAmountOut(amount0In, reserve0, reserve1);
        
        console.log(`🔄 Arbitrage: Selling ${amount0In / 10**6} USDT for ${amount1Out / 10**6} TRX`);
        
        await fakePair.swap(0, amount1Out, tronWeb.defaultAddress.base58, '0x').send({
            feeLimit: 100_000_000,
            callValue: 0
        });
        
    } else {
        // USDT is underpriced, buy USDT with TRX
        const amount1In = swapSize;
        const amount0Out = getAmountOut(amount1In, reserve1, reserve0);
        
        console.log(`🔄 Arbitrage: Buying ${amount0Out / 10**6} USDT with ${amount1In / 10**6} TRX`);
        
        await fakePair.swap(amount0Out, 0, tronWeb.defaultAddress.base58, '0x').send({
            feeLimit: 100_000_000,
            callValue: 0
        });
    }
}

/**
 * Perform organic swap for realistic activity
 */
async function performOrganicSwap(reserve0, reserve1) {
    // Generate random swap size (0.1% to 1% of reserves)
    const swapPercent = 0.001 + Math.random() * 0.009;
    const isToken0ToToken1 = Math.random() > 0.5;
    
    if (isToken0ToToken1) {
        const amount0In = Math.floor(reserve0 * swapPercent);
        const amount1Out = getAmountOut(amount0In, reserve0, reserve1);
        
        console.log(`🔄 Organic swap: ${amount0In / 10**6} USDT → ${amount1Out / 10**6} TRX`);
        
        // Emit swap event
        await emitSwapEvent(amount0In, 0, 0, amount1Out);
        
    } else {
        const amount1In = Math.floor(reserve1 * swapPercent);
        const amount0Out = getAmountOut(amount1In, reserve1, reserve0);
        
        console.log(`🔄 Organic swap: ${amount1In / 10**6} TRX → ${amount0Out / 10**6} USDT`);
        
        // Emit swap event
        await emitSwapEvent(0, amount1In, amount0Out, 0);
    }
    
    // Update 24h volume
    botState.totalVolume24h += isToken0ToToken1 ? 
        (amount0In / 10**6 * botState.lastPrice) : 
        (amount0Out / 10**6 * botState.lastPrice);
}

/**
 * Generate liquidity add/remove events
 */
async function generateLiquidityActivity() {
    try {
        const isAddLiquidity = Math.random() > 0.3; // 70% add, 30% remove
        
        if (isAddLiquidity) {
            await addLiquidity();
        } else {
            await removeLiquidity();
        }
        
        botState.liquidityEvents++;
        
    } catch (error) {
        console.error('❌ Liquidity generation error:', error);
    }
}

/**
 * Add liquidity to the pool
 */
async function addLiquidity() {
    const reserves = await fakePair.getReserves().call();
    const reserve0 = parseInt(reserves._reserve0);
    const reserve1 = parseInt(reserves._reserve1);
    
    // Random liquidity amount (0.5% to 2% of pool)
    const liquidityPercent = 0.005 + Math.random() * 0.015;
    const amount0 = Math.floor(reserve0 * liquidityPercent);
    const amount1 = Math.floor(reserve1 * liquidityPercent);
    
    console.log(`➕ Adding liquidity: ${amount0 / 10**6} USDT + ${amount1 / 10**6} TRX`);
    
    // Calculate LP tokens
    const totalSupply = await fakePair.totalSupply().call();
    const liquidity = Math.min(
        amount0 * totalSupply / reserve0,
        amount1 * totalSupply / reserve1
    );
    
    // Emit mint event
    await emitMintEvent(amount0, amount1);
}

/**
 * Remove liquidity from the pool
 */
async function removeLiquidity() {
    const totalSupply = await fakePair.totalSupply().call();
    
    // Random removal (0.5% to 1.5% of total supply)
    const removePercent = 0.005 + Math.random() * 0.01;
    const liquidity = Math.floor(totalSupply * removePercent);
    
    const reserves = await fakePair.getReserves().call();
    const amount0 = liquidity * reserves._reserve0 / totalSupply;
    const amount1 = liquidity * reserves._reserve1 / totalSupply;
    
    console.log(`➖ Removing liquidity: ${amount0 / 10**6} USDT + ${amount1 / 10**6} TRX`);
    
    // Emit burn event
    await emitBurnEvent(amount0, amount1);
}

/**
 * Emit realistic swap event
 */
async function emitSwapEvent(amount0In, amount1In, amount0Out, amount1Out) {
    // In production, this would call the contract
    // For now, we'll simulate the event emission
    console.log(`📢 Swap Event: In(${amount0In}, ${amount1In}) Out(${amount0Out}, ${amount1Out})`);
    
    // Update reserves based on swap
    await updateReserves();
}

/**
 * Emit mint event
 */
async function emitMintEvent(amount0, amount1) {
    console.log(`📢 Mint Event: ${amount0} + ${amount1}`);
    await updateReserves();
}

/**
 * Emit burn event
 */
async function emitBurnEvent(amount0, amount1) {
    console.log(`📢 Burn Event: ${amount0} + ${amount1}`);
    await updateReserves();
}

/**
 * Update reserves and emit sync event
 */
async function updateReserves() {
    try {
        await fakePair.sync().send({
            feeLimit: 100_000_000,
            callValue: 0
        });
        console.log('📊 Reserves synced');
    } catch (error) {
        console.error('❌ Sync error:', error);
    }
}

/**
 * Calculate arbitrage swap size
 */
function calculateArbitrageSize(currentPrice, targetPrice, reserve0, reserve1) {
    const priceDiff = Math.abs(currentPrice - targetPrice);
    const impactFactor = 0.01; // 1% max impact
    
    return Math.floor(Math.min(
        reserve0 * impactFactor,
        reserve1 * impactFactor * targetPrice
    ));
}

/**
 * Calculate output amount for swap (with 0.3% fee)
 */
function getAmountOut(amountIn, reserveIn, reserveOut) {
    const amountInWithFee = amountIn * 997;
    const numerator = amountInWithFee * reserveOut;
    const denominator = reserveIn * 1000 + amountInWithFee;
    return Math.floor(numerator / denominator);
}

/**
 * Generate MEV-style sandwich attacks (for realism)
 */
async function generateMEVActivity() {
    if (Math.random() > 0.95) { // 5% chance
        console.log('🥪 Simulating MEV sandwich attack...');
        
        // Front-run transaction
        await performOrganicSwap(1000000 * 10**6, 333333 * 10**6);
        
        // Victim transaction
        await performOrganicSwap(1000000 * 10**6, 333333 * 10**6);
        
        // Back-run transaction
        await performOrganicSwap(1000000 * 10**6, 333333 * 10**6);
    }
}

/**
 * Main bot loop
 */
async function runBot() {
    if (!botState.isRunning) return;
    
    console.log(`\n🤖 Bot cycle #${botState.swapCount + 1} at ${new Date().toISOString()}`);
    console.log(`📊 24h Volume: $${botState.totalVolume24h.toFixed(2)}`);
    
    try {
        // Update prices
        await monitorRealUSDT();
        
        // Generate activity based on weighted probability
        const rand = Math.random();
        
        if (rand < 0.6) {
            // 60% chance of swap
            await generateSwapActivity();
        } else if (rand < 0.85) {
            // 25% chance of liquidity event
            await generateLiquidityActivity();
        } else if (rand < 0.95) {
            // 10% chance of multiple swaps
            for (let i = 0; i < 3; i++) {
                await generateSwapActivity();
                await new Promise(resolve => setTimeout(resolve, 5000));
            }
        } else {
            // 5% chance of MEV activity
            await generateMEVActivity();
        }
        
        botState.lastActivity = Date.now();
        
    } catch (error) {
        console.error('❌ Bot cycle error:', error);
    }
}

/**
 * Schedule bot runs
 */
function scheduleBot() {
    // Run every 60 seconds with some randomness
    cron.schedule('*/1 * * * *', async () => {
        const delay = Math.random() * 15000; // 0-15 second random delay
        setTimeout(runBot, delay);
    });
    
    // Run immediately
    runBot();
    
    console.log('⏰ Bot scheduled to run every ~60 seconds');
}

/**
 * Graceful shutdown
 */
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down bot...');
    botState.isRunning = false;
    
    console.log(`📊 Final stats:`);
    console.log(`   Total swaps: ${botState.swapCount}`);
    console.log(`   Liquidity events: ${botState.liquidityEvents}`);
    console.log(`   24h Volume: $${botState.totalVolume24h.toFixed(2)}`);
    
    process.exit(0);
});

/**
 * Error recovery
 */
process.on('uncaughtException', (error) => {
    console.error('❌ Uncaught exception:', error);
    // Attempt to recover
    setTimeout(() => {
        console.log('🔄 Attempting to restart bot...');
        initializeBot().then(scheduleBot);
    }, 5000);
});

// Start the bot
console.log('🚀 Starting USDT Clone Liquidity Bot...');
initializeBot().then(scheduleBot);