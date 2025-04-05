# Bitfolio Protocol - Automated Portfolio Management System

[![Built with Clarity](https://img.shields.io/badge/Built_with-Clarity-3C3C3D)](https://clarity-lang.org)
[![Stacks L2 Compatible](https://img.shields.io/badge/Stacks_L2-Integrated-5546FF)](https://www.stacks.co)

**Enterprise-grade portfolio management infrastructure for Bitcoin DeFi**  
A non-custodial protocol enabling automated rebalancing of multi-asset portfolios on Stacks Layer 2.

## Key Features

### Portfolio Engine Core

- **Custom Portfolio Creation**: Deploy portfolios with up to 10 assets
- **Basis Point Precision**: 0.01% allocation granularity (10,000 BPS scale)
- **Time-Locked Rebalancing**: 24-hour minimum interval enforcement
- **Non-Custodial Architecture**: Users retain full asset control
- **Protocol Fee Mechanism**: 0.25% fee on transactions (configurable)

### Technical Architecture

- **Error Code System**: 11 standardized error states
- **Optimized Storage**: Dual-map structure for portfolio metadata/assets
- **Principal-Based Access Control**: Stacks-native authorization system
- **Portfolio Indexing**: User-specific portfolio registry with 20-portfolio cap

## Technical Specifications

### Core Components

| Component           | Type          | Description                            |
| ------------------- | ------------- | -------------------------------------- |
| `protocol-owner`    | Data Variable | Admin principal address                |
| `portfolio-counter` | Data Variable | Global ID tracker                      |
| `protocol-fee`      | Data Variable | Basis points fee (default: 25 = 0.25%) |
| `Portfolios`        | Data Map      | Portfolio metadata storage             |
| `PortfolioAssets`   | Data Map      | Asset allocation records               |
| `UserPortfolios`    | Data Map      | User-portfolio index                   |

## Functions Overview

### Read-Only Functions

| Function                      | Purpose                        |
| ----------------------------- | ------------------------------ |
| `get-portfolio`               | Retrieve portfolio metadata    |
| `get-portfolio-asset`         | Fetch asset allocation details |
| `get-user-portfolios`         | List user's portfolio IDs      |
| `calculate-rebalance-amounts` | Check rebalance eligibility    |

### Public Functions

| Function                      | Parameters                  | Key Checks                                                     |
| ----------------------------- | --------------------------- | -------------------------------------------------------------- |
| `create-portfolio`            | (tokens[], percentages[])   | - 10 asset max<br>- Percentage validation<br>- Length matching |
| `rebalance-portfolio`         | (portfolio-id)              | - Ownership check<br>- 24h cooldown                            |
| `update-portfolio-allocation` | (portfolio-id, token-id, %) | - Valid percentage<br>- Token ID exists                        |

### Admin Functions

| Function     | Parameters  | Governance Rules                             |
| ------------ | ----------- | -------------------------------------------- |
| `initialize` | (new-owner) | - Existing owner only<br>- Non-self transfer |

## Error Reference

| Code | Constant                 | Trigger Condition                 |
| ---- | ------------------------ | --------------------------------- |
| u100 | ERR-NOT-AUTHORIZED       | Unauthorized access attempt       |
| u101 | ERR-INVALID-PORTFOLIO    | Nonexistent portfolio ID          |
| u102 | ERR-INSUFFICIENT-BALANCE | Wallet funding shortage           |
| u103 | ERR-INVALID-TOKEN        | Unsupported token contract        |
| u106 | ERR-INVALID-PERCENTAGE   | Allocation outside 0-100% range   |
| u110 | ERR-INVALID-TOKEN-ID     | Nonexistent asset ID in portfolio |

## Security Model

### Core Protections

1. **Reentrancy Guards**: Native Clarity safety against reentrancy attacks
2. **Time-Locks**: 144-block (24h) minimum rebalance interval
3. **Precision Control**: All math operations use basis points (no decimals)
4. **Asset Caps**: Maximum 10 assets/portfolio prevents gas griefing

## Development Guide

### Local Environment Setup

1. Install [Clarinet](https://github.com/hirosystems/clarinet)
2. Initialize project:

```bash
clarinet new bitfolio && cd bitfolio
clarinet contract new portfolio-engine
```
