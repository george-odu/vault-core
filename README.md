# VaultCore Protocol

## Overview

VaultCore is a next-generation synthetic asset protocol built on Stacks that enables Bitcoin holders to unlock liquidity through over-collateralized synthetic USD creation while maintaining BTC exposure and earning yield through automated market making.

## 🎯 Key Features

- **Over-collateralized Synthetic Assets**: Create synthetic USD with 150% minimum collateralization ratio
- **Automated Liquidation Protection**: Safety threshold at 130% collateral ratio
- **Dynamic AMM**: Built-in automated market maker with 0.3% fee structure
- **Oracle-driven Pricing**: Secure price feeds with comprehensive validations
- **Permissionless Liquidity Provision**: Earn yield through LP token rewards
- **Gas-optimized Operations**: Cost-effective interactions for all users

## 🏗️ System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Bitcoin       │    │   VaultCore     │    │   Synthetic     │
│   Collateral    │───▶│   Protocol      │───▶│   USD Tokens    │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              │
                       ┌─────────────────┐
                       │   AMM Liquidity │
                       │   Pool          │
                       │                 │
                       └─────────────────┘
```

### Core Components

1. **Vault Management System**: Handles collateral deposits and synthetic asset minting
2. **Oracle Price Management**: Secure BTC/USD price feed updates
3. **Automated Market Maker**: Provides liquidity and trading functionality
4. **Risk Management**: Automated liquidation protection and collateral monitoring

## 💼 Contract Architecture

### State Variables

- `contract-initialized`: Protocol initialization status
- `oracle-price`: Current BTC/USD price feed
- `total-supply`: Total synthetic USD supply
- `pool-btc-balance`: AMM BTC reserves
- `pool-stable-balance`: AMM synthetic USD reserves

### Data Structures

#### Collateral Vaults

```clarity
{
  btc-locked: uint,           ;; Bitcoin collateral amount
  stablecoin-minted: uint,    ;; Synthetic USD minted
  last-update-height: uint    ;; Last transaction block height
}
```

#### Liquidity Providers

```clarity
{
  pool-tokens: uint,          ;; LP token balance
  btc-provided: uint,         ;; BTC provided to pool
  stable-provided: uint       ;; Synthetic USD provided to pool
}
```

## 🔄 Data Flow

### Minting Synthetic USD

1. User deposits Bitcoin collateral (`deposit-collateral`)
2. System validates minimum deposit requirements
3. User mints synthetic USD (`mint-stablecoin`)
4. Protocol checks collateralization ratio (≥150%)
5. Synthetic USD tokens are created and assigned to user

### Liquidity Provision

1. User provides BTC and synthetic USD to AMM (`add-liquidity`)
2. System calculates LP tokens using geometric mean formula
3. User receives proportional LP tokens
4. Liquidity earns fees from trading activity

### Liquidation Protection

- Automated monitoring of collateral ratios
- Liquidation threshold at 130% collateralization
- Early warning system for vault health

## 📊 Protocol Constants

| Parameter | Value | Description |
|-----------|-------|-------------|
| Minimum Collateral Ratio | 150% | Required over-collateralization |
| Liquidation Ratio | 130% | Automatic liquidation threshold |
| Minimum Deposit | 0.01 BTC | Minimum collateral deposit |
| Pool Fee Rate | 0.3% | AMM trading fee |
| Precision | 6 decimals | Calculation precision |
| Max Price | $1M USD | Maximum oracle price |
| Max Mint Amount | $10K USD | Maximum synthetic USD mint |

## 🚀 Getting Started

### Prerequisites

- Stacks wallet
- Bitcoin for collateral
- Basic understanding of DeFi protocols

### Initialization

```clarity
;; Initialize protocol with starting BTC price
(contract-call? .vault-core initialize u5000000000) ;; $50,000 USD
```

### Basic Usage

#### 1. Deposit Collateral

```clarity
;; Deposit 0.1 BTC as collateral
(contract-call? .vault-core deposit-collateral u10000000)
```

#### 2. Mint Synthetic USD

```clarity
;; Mint 2000 synthetic USD
(contract-call? .vault-core mint-stablecoin u2000000000)
```

#### 3. Provide Liquidity

```clarity
;; Add liquidity to AMM pool
(contract-call? .vault-core add-liquidity u5000000 u1500000000)
```

## 🔍 View Functions

### Get Vault Details

```clarity
(contract-call? .vault-core get-vault-details 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KX975CN0QKK6)
```

### Check Collateral Ratio

```clarity
(contract-call? .vault-core get-collateral-ratio 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KX975CN0QKK6)
```

### Pool Statistics

```clarity
(contract-call? .vault-core get-pool-details)
```

## ⚠️ Risk Management

### Collateralization Requirements

- **Minimum Ratio**: 150% to mint synthetic USD
- **Liquidation Threshold**: 130% triggers automatic liquidation
- **Safety Buffer**: Maintain >150% ratio to avoid liquidation risk

### Price Oracle Security

- Owner-controlled price updates for security
- Price validation mechanisms
- Maximum price limits to prevent manipulation

## 🛠️ Development

### Running Tests

```bash
npm test
```

### Contract Validation

```bash
clarinet check
```

### Project Structure

```
vault-core/
├── contracts/
│   └── vault-core.clar          # Main protocol contract
├── tests/
│   └── vault-core.test.ts       # Comprehensive test suite
├── settings/
│   ├── Devnet.toml             # Development network config
│   ├── Testnet.toml            # Testnet configuration
│   └── Mainnet.toml            # Mainnet configuration
├── Clarinet.toml               # Clarinet project config
└── package.json                # Node.js dependencies
```

## 📈 Economic Model

### Revenue Streams

- AMM trading fees (0.3% per swap)
- Liquidation penalties
- Protocol treasury management

### Yield Generation

- Liquidity providers earn trading fees
- Proportional reward distribution
- Compound yield through LP token appreciation

## 🔒 Security Features

- **Over-collateralization**: Protects against price volatility
- **Automated Liquidations**: Prevents bad debt accumulation
- **Oracle Validation**: Multi-layer price feed security
- **Access Control**: Owner-only critical functions
- **Balance Verification**: Comprehensive balance tracking

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## ⚡ Performance Metrics

- **Gas Optimization**: Minimized computational overhead
- **Scalability**: Designed for high transaction volume
- **Capital Efficiency**: Maximized collateral utilization
- **Liquidation Speed**: Sub-block liquidation capabilities
