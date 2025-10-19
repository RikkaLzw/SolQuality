# SolQuality - Solidity Smart Contract Quality Dataset

## 📋 Project Overview

SolQuality is a Solidity smart contract quality comparison dataset containing **25 types** of smart contracts, with each contract providing both **good practice** and **bad practice** versions, covering **6 major categories** of code quality issues.

**Dataset Size**: 1,200 contract files (200 per category, 100 good/100 bad each)

## 📂 Project Structure

```
SolQuality/
├── architecture/      # Architecture Design (200 contracts)
├── datatype/         # Data Type Usage (200 contracts)
├── efficiency/       # Efficiency & Performance (200 contracts)
├── event/           # Event Usage (200 contracts)
├── function/        # Function Design (200 contracts)
└── readability/     # Code Readability (200 contracts)
```

Each directory contains `bad/` and `good/` subfolders, storing contracts with poor practices and best practices respectively.

## 🔍 Six Quality Categories

| Category | Main Issues |
|------|---------|
| **Architecture** | Modular design, single responsibility, access control, inheritance structure |
| **DataType** | Type selection, overflow risks, type conversion, storage optimization |
| **Efficiency** | Storage read/write, loop optimization, gas consumption, data structures |
| **Event** | Event logging, parameter completeness, indexed usage, naming conventions |
| **Function** | Function responsibility, visibility, parameter validation, return value handling |
| **Readability** | Naming conventions, code comments, formatting, magic numbers |

## 💼 25 Smart Contract Types

NFT Collection, ERC20 Token, Multi-Sig Wallet, Staking Rewards, Lending Protocol, Liquidity Pool, DEX, DAO Governance, Voting System, Auction System, Insurance, Supply Chain, Payment Distribution, Token Vesting, Oracle, Identity, Membership System, Points System, Game Item, Copyright, Order Management, Real Estate, Crowdfunding, Time Lock, AMM


## ⚠️ Important Notes

- Contracts in the bad folder are for learning purposes only; DO NOT deploy to production
- This dataset focuses on code quality and does not cover security vulnerabilities (e.g., reentrancy attacks)

## 📝 License

MIT License

---

**Disclaimer**: This project is for educational and research purposes only.
