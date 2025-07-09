const axios = require("axios");
const fs = require("fs");

async function updatePairs() {
    const url = "https://api.dexscreener.com/latest/dex/pairs/polygon";
    const { data } = await axios.get(url);
    const PAIRS_LIMIT = 25;
    const MIN_LIQ_USD = 20000;
    const pairs = data.pairs
        .filter(pair => Number(pair.liquidity.usd) >= MIN_LIQ_USD)
        .slice(0, PAIRS_LIMIT)
        .map(pair => ({
            base: pair.baseToken.address,
            baseSymbol: pair.baseToken.symbol,
            baseDecimals: pair.baseToken.decimals,
            pair: pair.quoteToken.address,
            pairSymbol: pair.quoteToken.symbol,
            pairDecimals: pair.quoteToken.decimals
        }));
    fs.writeFileSync("pairs.json", JSON.stringify(pairs, null, 2));
    console.log(`Updated pairs.json with ${pairs.length} pairs.`);
}

async function updateDexRouters() {
    const routers = [
        { name: "QuickSwap", address: "0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff" },
        { name: "SushiSwap", address: "0x1b02da8cb0d097eb8d57a175b88c7d8b47997506" },
        { name: "Dfyn", address: "0xa102072a4c07f06ec3b4900fdc4c7b80b6c57429" }
        // ... (add more as needed)
    ];
    fs.writeFileSync("dexRouters.json", JSON.stringify(routers, null, 2));
    console.log(`Updated dexRouters.json with ${routers.length} routers.`);
}

(async () => {
    await updatePairs();
    await updateDexRouters();
})();