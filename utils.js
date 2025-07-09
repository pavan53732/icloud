const ethers = require("ethers");
const nodemailer = require("nodemailer");
const fs = require("fs");
const config = require("./config.json");

let metrics = { trades: 0, wins: 0, losses: 0, totalProfit: 0, lastProfit: 0 };

async function estimateGasUsd(provider, gasLimit, chainlinkOracle) {
    const gasPrice = await provider.getGasPrice();
    const aggregator = new ethers.Contract(
        chainlinkOracle,
        ["function latestAnswer() view returns (int256)"],
        provider
    );
    const maticUsd = Number(await aggregator.latestAnswer()) / 1e8;
    const gasCost = Number(gasPrice) * gasLimit / 1e18;
    return { usd: gasCost * maticUsd, gasPrice };
}

function logTrade(event, data) {
    const logLine = `[${new Date().toISOString()}] ${event}: ${JSON.stringify(data)}\n`;
    fs.appendFileSync("trades.log", logLine);
    if (event === "Trade executed") {
        metrics.trades += 1;
        metrics.lastProfit = data.profitUsd || 0;
        metrics.totalProfit += data.profitUsd || 0;
        if ((data.profitUsd || 0) > 0) metrics.wins += 1;
        else metrics.losses += 1;
        fs.writeFileSync("metrics.json", JSON.stringify(metrics, null, 2));
    }
}

function getMetrics() {
    return metrics;
}

module.exports = { estimateGasUsd, logTrade, getMetrics };