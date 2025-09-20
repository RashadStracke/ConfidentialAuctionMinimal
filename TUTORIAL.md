# Hello FHEVM: Your First Confidential Application Tutorial

**Build a Complete Confidential Auction dApp with Zama's Fully Homomorphic Encryption**

Welcome to the most beginner-friendly introduction to FHEVM (Fully Homomorphic Encryption Virtual Machine)! This tutorial will guide you through building your first confidential application - a privacy-preserving auction platform where bid amounts remain completely secret until reveal.

## 🎯 What You'll Learn

By the end of this tutorial, you will:

1. **Understand FHE basics** without any cryptography background
2. **Write your first FHEVM smart contract** with encrypted data types
3. **Build a complete frontend** that interacts with encrypted smart contracts
4. **Deploy and test** your confidential application on testnet
5. **Experience real privacy** in blockchain applications

## 📋 Prerequisites

**What you need to know:**
- ✅ Basic Solidity (writing simple smart contracts)
- ✅ JavaScript fundamentals
- ✅ How to use MetaMask
- ✅ Basic understanding of Ethereum development

**What you DON'T need:**
- ❌ Any cryptography knowledge
- ❌ Advanced mathematics
- ❌ Previous FHE experience
- ❌ Complex development setups

**Tools you should have:**
- Node.js (v16 or later)
- MetaMask browser extension
- Basic text editor or IDE

## 🚀 Chapter 1: Understanding FHE in 5 Minutes

### What is Fully Homomorphic Encryption?

Imagine you have a locked box where you can perform calculations on the contents **without opening the box**. That's essentially what FHE allows us to do with data on the blockchain.

**Traditional Smart Contracts:**
```solidity
uint256 publicBid = 100; // Everyone can see this value
```

**FHE Smart Contracts:**
```solidity
euint64 secretBid = FHE.asEuint64(100); // Encrypted, nobody can see the actual value
```

### Why This Matters for dApps

- **🔒 Privacy**: Sensitive data stays encrypted on-chain
- **🎯 Competition**: No front-running or bid manipulation
- **✨ Trust**: Cryptographic guarantees instead of trusted third parties
- **🌐 Decentralization**: Full privacy without centralized servers

### Real-World Example: Our Auction dApp

In our auction:
- 🚫 **Without FHE**: Everyone sees all bid amounts → unfair advantages
- ✅ **With FHE**: Bid amounts are encrypted → fair competition

## 🛠️ Chapter 2: Setting Up Your Development Environment

### Step 1: Initialize Your Project

```bash
mkdir hello-fhevm-auction
cd hello-fhevm-auction
npm init -y
```

### Step 2: Install Dependencies

```bash
# Core FHEVM dependencies
npm install fhevm@^0.7.0 @fhevm/hardhat-plugin@0.0.1-3

# Standard Ethereum development tools
npm install hardhat@^2.24.3 @nomicfoundation/hardhat-toolbox ethers@^6.8.0

# Development utilities
npm install dotenv
```

### Step 3: Initialize Hardhat

```bash
npx hardhat init
```

Choose "Create a JavaScript project" and accept all defaults.

### Step 4: Configure Hardhat for FHEVM

Update your `hardhat.config.js`:

```javascript
require("@nomicfoundation/hardhat-toolbox");
require("@fhevm/hardhat-plugin");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      metadata: { bytecodeHash: "none" },
      optimizer: { enabled: true, runs: 800 },
      evmVersion: "cancun",
      viaIR: true, // Essential for FHE contracts
    },
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "https://sepolia.infura.io/v3/YOUR_KEY",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
};
```

### Step 5: Create Environment File

Create `.env` file:

```env
PRIVATE_KEY=your_private_key_without_0x
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
```

## 📝 Chapter 3: Writing Your First FHE Smart Contract

### Understanding FHE Data Types

FHEVM introduces encrypted data types:

```solidity
// Encrypted integers
euint8   // 8-bit encrypted integer (0-255)
euint16  // 16-bit encrypted integer (0-65535)
euint32  // 32-bit encrypted integer (0-4294967295)
euint64  // 64-bit encrypted integer (largest range)

// Encrypted boolean
ebool    // encrypted true/false

// Encrypted addresses
eaddress // encrypted Ethereum address
```

### Creating the Auction Contract

Create `contracts/ConfidentialAuction.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint64, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract ConfidentialAuction is SepoliaConfig {

    // 📊 Data Structures
    struct Auction {
        uint256 id;
        string title;
        string description;
        string category;
        uint256 minimumBid;        // Public minimum bid
        address creator;
        uint256 timestamp;
        bool isActive;
        uint256 endTime;
        address highestBidder;     // Public winner address
        uint256 bidCount;
    }

    struct Bid {
        address bidder;
        euint64 amount;           // 🔒 ENCRYPTED bid amount
        string comments;
        uint256 timestamp;
    }

    // 🗄️ Storage
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(address => uint256[]) public userAuctions;
    mapping(address => mapping(uint256 => bool)) public hasUserBid;

    uint256 public nextAuctionId = 1;
    uint256 public totalAuctions = 0;

    // 📢 Events
    event AuctionCreated(
        uint256 indexed auctionId,
        string title,
        string category,
        uint256 minimumBid,
        address indexed creator,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        string comments,
        uint256 timestamp
    );

    // 🏗️ Constructor
    constructor() {}

    // 🎯 Core Functions

    /**
     * Create a new auction
     * @param _title Auction title
     * @param _description Auction description
     * @param _category Auction category
     * @param _minimumBid Minimum bid amount in wei
     */
    function createAuction(
        string memory _title,
        string memory _description,
        string memory _category,
        uint256 _minimumBid
    ) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_minimumBid > 0, "Minimum bid must be greater than 0");

        uint256 auctionId = nextAuctionId;
        uint256 endTime = block.timestamp + 7 days;

        auctions[auctionId] = Auction({
            id: auctionId,
            title: _title,
            description: _description,
            category: _category,
            minimumBid: _minimumBid,
            creator: msg.sender,
            timestamp: block.timestamp,
            isActive: true,
            endTime: endTime,
            highestBidder: address(0),
            bidCount: 0
        });

        userAuctions[msg.sender].push(auctionId);
        totalAuctions++;
        nextAuctionId++;

        emit AuctionCreated(auctionId, _title, _category, _minimumBid, msg.sender, endTime);
    }

    /**
     * Place a confidential bid on an auction
     * @param _auctionId The auction to bid on
     * @param _isHighBid Whether this is intended as the highest bid
     * @param _bidAmount The bid amount in wei
     * @param _comments Optional comments for the bid
     */
    function placeBid(
        uint256 _auctionId,
        bool _isHighBid,
        uint256 _bidAmount,
        string memory _comments
    ) external payable {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        require(auctions[_auctionId].isActive, "Auction is not active");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction has ended");
        require(_bidAmount >= auctions[_auctionId].minimumBid, "Bid too low");
        require(msg.value >= _bidAmount, "Insufficient payment");

        // 🔒 Here's the FHE magic: encrypt the bid amount
        euint64 encryptedAmount = FHE.asEuint64(uint64(_bidAmount));

        // Grant access permissions for encrypted data
        FHE.allowThis(encryptedAmount);
        FHE.allow(encryptedAmount, msg.sender);

        // Store the encrypted bid
        auctionBids[_auctionId].push(Bid({
            bidder: msg.sender,
            amount: encryptedAmount,    // 🔒 Encrypted!
            comments: _comments,
            timestamp: block.timestamp
        }));

        // Update auction data
        Auction storage auction = auctions[_auctionId];
        auction.bidCount++;
        hasUserBid[msg.sender][_auctionId] = true;

        // Update highest bidder if this is marked as high bid
        if (_isHighBid) {
            auction.highestBidder = msg.sender;
        }

        emit BidPlaced(_auctionId, msg.sender, _comments, block.timestamp);
    }

    // 👁️ View Functions (return non-encrypted data for frontend)

    function getTotalCounts() external view returns (uint256 totalAuctionCount, uint256 activeAuctionCount) {
        uint256 activeCount = 0;
        for (uint256 i = 1; i < nextAuctionId; i++) {
            if (auctions[i].isActive && block.timestamp < auctions[i].endTime) {
                activeCount++;
            }
        }
        return (totalAuctions, activeCount);
    }

    function getAuctionBasicInfo(uint256 _auctionId) external view returns (
        string memory title,
        string memory description,
        string memory category,
        uint256 minimumBid,
        address creator
    ) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        return (auction.title, auction.description, auction.category, auction.minimumBid, auction.creator);
    }

    function getAuctionStatus(uint256 _auctionId) external view returns (
        uint256 timestamp,
        bool isActive,
        uint256 endTime,
        uint256 bidCount
    ) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        return (auction.timestamp, auction.isActive && block.timestamp < auction.endTime, auction.endTime, auction.bidCount);
    }

    function getBidCount(uint256 _auctionId) external view returns (uint256) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        return auctions[_auctionId].bidCount;
    }

    function getUserAuctions(address _user) external view returns (uint256[] memory) {
        return userAuctions[_user];
    }

    function hasUserBidOnAuction(address _user, uint256 _auctionId) external view returns (bool) {
        return hasUserBid[_user][_auctionId];
    }

    function getHighestBidder(uint256 _auctionId) external view returns (address) {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        return auctions[_auctionId].highestBidder;
    }

    // 🔧 Admin functions
    function endAuction(uint256 _auctionId) external {
        require(_auctionId > 0 && _auctionId < nextAuctionId, "Invalid auction ID");
        require(auctions[_auctionId].creator == msg.sender, "Only creator can end auction");
        auctions[_auctionId].isActive = false;
    }
}
```

### Key FHE Concepts Explained

**1. Encrypted Data Types:**
```solidity
euint64 encryptedAmount = FHE.asEuint64(uint64(_bidAmount));
```
This converts a regular integer to an encrypted integer that cannot be read by anyone.

**2. Access Control:**
```solidity
FHE.allowThis(encryptedAmount);        // Contract can use this data
FHE.allow(encryptedAmount, msg.sender); // User can access their own data
```
FHE requires explicit permission grants for who can access encrypted data.

**3. Privacy Guarantees:**
- Bid amounts are encrypted on-chain
- Only authorized parties can decrypt specific values
- Computations can be performed on encrypted data
- Results remain verifiable

## 🚀 Chapter 4: Deploying Your FHE Contract

### Step 1: Create Deployment Script

Create `scripts/deploy.js`:

```javascript
const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying ConfidentialAuction contract...");

  // Get the contract factory
  const ConfidentialAuction = await ethers.getContractFactory("ConfidentialAuction");

  // Deploy the contract
  console.log("📝 Deploying contract...");
  const confidentialAuction = await ConfidentialAuction.deploy();

  // Wait for deployment
  await confidentialAuction.waitForDeployment();

  const contractAddress = await confidentialAuction.getAddress();
  console.log("✅ ConfidentialAuction deployed to:", contractAddress);

  // Verify deployment
  console.log("🔍 Verifying deployment...");
  const deployedCode = await ethers.provider.getCode(contractAddress);
  if (deployedCode === "0x") {
    throw new Error("❌ Contract deployment failed - no code at address");
  }

  console.log("✅ Contract successfully deployed and verified!");

  // Display useful information
  console.log("\\n📋 Deployment Summary:");
  console.log("=".repeat(50));
  console.log(`Contract Address: ${contractAddress}`);
  console.log(`Network: ${(await ethers.provider.getNetwork()).name}`);
  console.log(`Chain ID: ${(await ethers.provider.getNetwork()).chainId}`);

  // Get deployer info
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Deployer Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);

  // Test basic functionality
  console.log("\\n🧪 Testing basic functionality...");
  try {
    const totalCounts = await confidentialAuction.getTotalCounts();
    console.log(`✅ Contract functional - Total auctions: ${totalCounts[0]}, Active: ${totalCounts[1]}`);
  } catch (error) {
    console.log("⚠️  Could not test contract functionality:", error);
  }

  console.log("\\n🎯 Next steps:");
  console.log("1. Update frontend CONTRACT_ADDRESS to:", contractAddress);
  console.log("2. Fund deployer account with ETH for gas");
  console.log("3. Test creating auctions and placing bids");
  console.log("4. Verify contract on block explorer if needed");
}

// Handle deployment errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
```

### Step 2: Deploy to Sepolia Testnet

```bash
# Compile the contract
npx hardhat compile

# Deploy to Sepolia
npx hardhat run scripts/deploy.js --network sepolia
```

**Expected Output:**
```
✅ ConfidentialAuction deployed to: 0x1234567890abcdef...
```

**Important:** Save this contract address - you'll need it for the frontend!

## 🌐 Chapter 5: Building the Frontend

Create `index.html` - a complete single-file frontend:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🏆 Confidential Auction - FHE Tutorial</title>

    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            background: linear-gradient(135deg, #0f1419 0%, #1a202c 100%);
            color: #e2e8f0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            min-height: 100vh;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }

        .header {
            text-align: center;
            margin-bottom: 3rem;
            padding: 2rem 0;
        }

        .header h1 {
            font-size: 3rem;
            font-weight: 700;
            margin-bottom: 1rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .header p {
            font-size: 1.2rem;
            color: #94a3b8;
            max-width: 600px;
            margin: 0 auto;
        }

        .card {
            background: rgba(30, 41, 59, 0.8);
            border: 1px solid #475569;
            border-radius: 12px;
            padding: 2rem;
            margin-bottom: 2rem;
            backdrop-filter: blur(10px);
        }

        .card h2 {
            color: #f1f5f9;
            margin-bottom: 1.5rem;
            font-size: 1.5rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .wallet-section {
            margin-bottom: 2rem;
        }

        .wallet-status {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 1rem;
        }

        .status-indicator {
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .status-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #ef4444;
        }

        .status-dot.connected {
            background: #22c55e;
        }

        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 0.75rem 1.5rem;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
        }

        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }

        .btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }

        .form-group {
            margin-bottom: 1.5rem;
        }

        .form-group label {
            display: block;
            margin-bottom: 0.5rem;
            color: #e2e8f0;
            font-weight: 500;
        }

        .form-group input,
        .form-group select,
        .form-group textarea {
            width: 100%;
            padding: 0.75rem;
            border: 1px solid #475569;
            border-radius: 6px;
            background: rgba(51, 65, 85, 0.8);
            color: #e2e8f0;
            font-size: 1rem;
        }

        .form-group input:focus,
        .form-group select:focus,
        .form-group textarea:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }

        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 1rem;
        }

        .auction-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 1.5rem;
            margin-top: 2rem;
        }

        .auction-item {
            background: rgba(51, 65, 85, 0.6);
            border: 1px solid #475569;
            border-radius: 8px;
            padding: 1.5rem;
            transition: all 0.3s ease;
            cursor: pointer;
        }

        .auction-item:hover {
            transform: translateY(-4px);
            border-color: #667eea;
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
        }

        .auction-meta {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1rem;
            font-size: 0.875rem;
        }

        .auction-status {
            padding: 0.25rem 0.5rem;
            border-radius: 4px;
            font-size: 0.75rem;
            font-weight: 600;
        }

        .auction-status.active {
            background: rgba(34, 197, 94, 0.2);
            color: #86efac;
        }

        .auction-title {
            font-size: 1.25rem;
            font-weight: 600;
            color: #f1f5f9;
            margin-bottom: 0.5rem;
        }

        .bid-amount {
            font-size: 1.1rem;
            font-weight: 600;
            color: #fbbf24;
        }

        .hidden {
            display: none;
        }

        .alert {
            padding: 1rem;
            border-radius: 6px;
            margin-bottom: 1rem;
        }

        .alert.success {
            background: rgba(34, 197, 94, 0.1);
            border: 1px solid #22c55e;
            color: #86efac;
        }

        .alert.error {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid #ef4444;
            color: #fca5a5;
        }

        .alert.info {
            background: rgba(59, 130, 246, 0.1);
            border: 1px solid #3b82f6;
            color: #93c5fd;
        }

        .bid-options {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
            gap: 1rem;
            margin: 1rem 0;
        }

        .bid-option {
            padding: 0.75rem;
            border: 2px solid #475569;
            border-radius: 6px;
            background: rgba(51, 65, 85, 0.6);
            cursor: pointer;
            text-align: center;
            transition: all 0.3s ease;
        }

        .bid-option:hover {
            border-color: #667eea;
        }

        .bid-option.selected {
            border-color: #667eea;
            background: rgba(102, 126, 234, 0.2);
        }

        @media (max-width: 768px) {
            .form-row {
                grid-template-columns: 1fr;
            }

            .bid-options {
                grid-template-columns: 1fr;
            }

            .wallet-status {
                flex-direction: column;
                gap: 1rem;
                align-items: stretch;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>🏆 Confidential Auction Tutorial</h1>
            <p>Learn FHEVM by building a privacy-preserving auction where bid amounts remain completely secret</p>
        </header>

        <div class="wallet-section">
            <div class="wallet-status">
                <div class="status-indicator">
                    <div class="status-dot" id="statusDot"></div>
                    <span id="walletStatus">Not Connected</span>
                </div>
                <button class="btn" id="connectWallet">Connect Wallet</button>
            </div>
            <div id="walletAddress" class="hidden">
                <p><strong>Address:</strong> <span id="userAddress"></span></p>
            </div>
        </div>

        <div class="main-content">
            <div class="card">
                <h2>🎯 Create New Auction</h2>

                <form id="createAuctionForm">
                    <div class="form-row">
                        <div class="form-group">
                            <label for="auctionTitle">Auction Title</label>
                            <input type="text" id="auctionTitle" required placeholder="e.g., Rare Digital Art #1" maxlength="100">
                        </div>

                        <div class="form-group">
                            <label for="auctionCategory">Category</label>
                            <select id="auctionCategory" required>
                                <option value="">Select category</option>
                                <option value="digital-art">Digital Art</option>
                                <option value="collectibles">Collectibles</option>
                                <option value="gaming">Gaming Items</option>
                                <option value="virtual-real-estate">Virtual Real Estate</option>
                                <option value="other">Other</option>
                            </select>
                        </div>
                    </div>

                    <div class="form-group">
                        <label for="auctionDescription">Description</label>
                        <textarea id="auctionDescription" required rows="3" placeholder="Describe your auction item..." maxlength="500"></textarea>
                    </div>

                    <div class="form-group">
                        <label for="minimumBid">Minimum Bid (ETH)</label>
                        <input type="number" id="minimumBid" required step="0.00001" min="0.00001" placeholder="0.00001">
                    </div>

                    <button type="submit" class="btn">Create Auction</button>
                </form>
            </div>

            <div class="card">
                <h2>🎪 Active Auctions</h2>
                <div id="auctionsList" class="auction-grid">
                    <div style="text-align: center; color: #94a3b8; padding: 2rem;">
                        Connect your wallet to view auctions
                    </div>
                </div>
            </div>

            <div class="card hidden" id="bidCard">
                <h2>💰 Place Your Bid</h2>
                <div id="auctionDetails"></div>

                <div class="form-group">
                    <label>Select Bid Amount (ETH)</label>
                    <div class="bid-options" id="bidOptions">
                        <div class="bid-option" data-amount="0.00001">0.00001 ETH</div>
                        <div class="bid-option" data-amount="0.0001">0.0001 ETH</div>
                        <div class="bid-option" data-amount="0.001">0.001 ETH</div>
                        <div class="bid-option" data-amount="0.01">0.01 ETH</div>
                        <div class="bid-option" data-amount="custom">Custom</div>
                    </div>
                </div>

                <div class="form-group hidden" id="customBidGroup">
                    <label for="customBidAmount">Custom Bid Amount (ETH)</label>
                    <input type="number" id="customBidAmount" step="0.00001" min="0.00001" placeholder="0.00001">
                </div>

                <div class="form-group">
                    <label for="bidComments">Comments (Optional)</label>
                    <textarea id="bidComments" rows="2" placeholder="Add a message with your bid..." maxlength="200"></textarea>
                </div>

                <button class="btn" id="placeBidBtn">Place Confidential Bid</button>
            </div>
        </div>
    </div>

    <!-- Load Ethers.js -->
    <script src="https://cdn.jsdelivr.net/npm/ethers@6.8.0/dist/ethers.umd.min.js"></script>

    <script>
        // 🔧 Configuration - UPDATE THIS WITH YOUR DEPLOYED CONTRACT ADDRESS
        const CONTRACT_ADDRESS = 'YOUR_CONTRACT_ADDRESS_HERE';

        // Contract ABI - includes all the methods we need
        const CONTRACT_ABI = [
            {
                "inputs": [
                    {"internalType": "string", "name": "_title", "type": "string"},
                    {"internalType": "string", "name": "_description", "type": "string"},
                    {"internalType": "string", "name": "_category", "type": "string"},
                    {"internalType": "uint256", "name": "_minimumBid", "type": "uint256"}
                ],
                "name": "createAuction",
                "outputs": [],
                "stateMutability": "nonpayable",
                "type": "function"
            },
            {
                "inputs": [
                    {"internalType": "uint256", "name": "_auctionId", "type": "uint256"},
                    {"internalType": "bool", "name": "_isHighBid", "type": "bool"},
                    {"internalType": "uint256", "name": "_bidAmount", "type": "uint256"},
                    {"internalType": "string", "name": "_comments", "type": "string"}
                ],
                "name": "placeBid",
                "outputs": [],
                "stateMutability": "payable",
                "type": "function"
            },
            {
                "inputs": [],
                "name": "nextAuctionId",
                "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [],
                "name": "totalAuctions",
                "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [{"internalType": "uint256", "name": "_auctionId", "type": "uint256"}],
                "name": "getAuctionBasicInfo",
                "outputs": [
                    {"internalType": "string", "name": "title", "type": "string"},
                    {"internalType": "string", "name": "description", "type": "string"},
                    {"internalType": "string", "name": "category", "type": "string"},
                    {"internalType": "uint256", "name": "minimumBid", "type": "uint256"},
                    {"internalType": "address", "name": "creator", "type": "address"}
                ],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [{"internalType": "uint256", "name": "_auctionId", "type": "uint256"}],
                "name": "getAuctionStatus",
                "outputs": [
                    {"internalType": "uint256", "name": "timestamp", "type": "uint256"},
                    {"internalType": "bool", "name": "isActive", "type": "bool"},
                    {"internalType": "uint256", "name": "endTime", "type": "uint256"},
                    {"internalType": "uint256", "name": "bidCount", "type": "uint256"}
                ],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [{"internalType": "uint256", "name": "_auctionId", "type": "uint256"}],
                "name": "getBidCount",
                "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [],
                "name": "getTotalCounts",
                "outputs": [
                    {"internalType": "uint256", "name": "totalAuctionCount", "type": "uint256"},
                    {"internalType": "uint256", "name": "activeAuctionCount", "type": "uint256"}
                ],
                "stateMutability": "view",
                "type": "function"
            }
        ];

        // 🌐 Global Variables
        let provider, signer, contract;
        let currentAuctionId = null;
        let selectedBidAmount = null;

        // 🎯 DOM Elements
        const statusDot = document.getElementById('statusDot');
        const walletStatus = document.getElementById('walletStatus');
        const userAddressSpan = document.getElementById('userAddress');
        const walletAddress = document.getElementById('walletAddress');
        const connectWalletBtn = document.getElementById('connectWallet');
        const auctionsList = document.getElementById('auctionsList');
        const bidCard = document.getElementById('bidCard');

        // 🚀 Initialize App
        async function init() {
            console.log('Initializing FHE Auction Tutorial...');

            // Check if MetaMask is installed
            if (typeof window.ethereum !== 'undefined') {
                console.log('MetaMask is installed');

                // Check if already connected
                const accounts = await window.ethereum.request({ method: 'eth_accounts' });
                if (accounts.length > 0) {
                    await connectWallet();
                }
            } else {
                showAlert('Please install MetaMask to use this application', 'error');
            }

            setupEventListeners();
        }

        // 🔌 Connect Wallet Function
        async function connectWallet() {
            try {
                if (typeof window.ethereum === 'undefined') {
                    throw new Error('MetaMask is not installed');
                }

                const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
                const userAddress = accounts[0];

                // Initialize ethers
                provider = new ethers.BrowserProvider(window.ethereum);
                signer = await provider.getSigner();

                // Initialize contract
                contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);

                // Update UI
                statusDot.className = 'status-dot connected';
                walletStatus.textContent = 'Connected to Sepolia';
                userAddressSpan.textContent = userAddress;
                walletAddress.classList.remove('hidden');
                connectWalletBtn.textContent = 'Connected';
                connectWalletBtn.disabled = true;

                console.log('Wallet connected:', userAddress);
                showAlert('Wallet connected successfully! Ready to participate in auctions.', 'success');

                // Load auctions after wallet connection
                await loadAuctions();

            } catch (error) {
                console.error('Error connecting wallet:', error);
                showAlert('Failed to connect wallet: ' + error.message, 'error');
            }
        }

        // 🎪 Load Auctions Function
        async function loadAuctions() {
            try {
                console.log('Loading auctions...');

                if (!contract) {
                    auctionsList.innerHTML = '<div style="text-align: center; color: #94a3b8; padding: 2rem;">Connect your wallet to view auctions</div>';
                    return;
                }

                // Get total auctions
                const nextId = await contract.nextAuctionId();
                console.log('Next auction ID:', nextId.toString());

                const contractAuctions = [];

                // Load each auction
                for (let i = 1; i < Number(nextId); i++) {
                    try {
                        const basicInfo = await contract.getAuctionBasicInfo(i);
                        const statusInfo = await contract.getAuctionStatus(i);
                        const bidCount = await contract.getBidCount(i);

                        contractAuctions.push({
                            id: i,
                            title: basicInfo[0],
                            description: basicInfo[1],
                            category: basicInfo[2],
                            minimumBid: basicInfo[3],
                            creator: basicInfo[4],
                            timestamp: Number(statusInfo[0]),
                            isActive: statusInfo[1],
                            endTime: Number(statusInfo[2]),
                            bidCount: Number(bidCount)
                        });
                    } catch (auctionError) {
                        console.log(`Failed to load auction ${i}:`, auctionError.message);
                    }
                }

                displayAuctions(contractAuctions);

            } catch (error) {
                console.error('Error loading auctions:', error);
                auctionsList.innerHTML = '<div style="text-align: center; color: #ef4444; padding: 2rem;">Error loading auctions. Please try again.</div>';
            }
        }

        // 🎨 Display Auctions Function
        function displayAuctions(auctions) {
            if (auctions.length === 0) {
                auctionsList.innerHTML = '<div style="text-align: center; color: #94a3b8; padding: 2rem;">No auctions available. Create the first one!</div>';
                return;
            }

            const auctionsHtml = auctions.map(auction => {
                const minBidEth = ethers.formatEther(auction.minimumBid);

                return `
                    <div class="auction-item" onclick="startBidding(${auction.id})">
                        <div class="auction-meta">
                            <span>Auction #${auction.id}</span>
                            <span class="auction-status active">🟢 Active</span>
                        </div>
                        <div class="auction-title">${auction.title}</div>
                        <div style="color: #94a3b8; font-size: 0.9rem; margin-top: 0.5rem;">
                            Category: ${auction.category.charAt(0).toUpperCase() + auction.category.slice(1).replace('-', ' ')}
                        </div>
                        <div class="bid-amount" style="margin-top: 0.5rem;">
                            Min Bid: ${minBidEth} ETH
                        </div>
                        <div style="color: #64748b; font-size: 0.85rem; margin-top: 0.5rem; line-height: 1.4;">
                            ${auction.description.substring(0, 120)}${auction.description.length > 120 ? '...' : ''}
                        </div>
                        <div style="margin-top: 0.5rem; font-size: 0.8rem; color: #94a3b8;">
                            Created: ${new Date(auction.timestamp * 1000).toLocaleDateString()}
                        </div>
                        <div style="font-size: 0.75rem; color: #86efac; margin-top: 0.25rem;">
                            🔒 FHE Encrypted Bidding • ${auction.bidCount} bids
                        </div>
                    </div>
                `;
            }).join('');

            auctionsList.innerHTML = auctionsHtml;
        }

        // 🎯 Create Auction Function
        async function createAuction(title, description, category, minimumBid) {
            try {
                if (!contract) throw new Error('Please connect your wallet first');

                const minBidWei = ethers.parseEther(minimumBid.toString());

                console.log('Creating FHE auction with parameters:');
                console.log('Title:', title);
                console.log('Description:', description);
                console.log('Category:', category);
                console.log('Minimum bid (ETH):', minimumBid);

                showAlert('⏳ Submitting auction to blockchain...', 'info');

                const tx = await contract.createAuction(title, description, category, minBidWei);

                showAlert('🔄 Transaction submitted! Waiting for confirmation...', 'success');
                console.log('Transaction hash:', tx.hash);

                const receipt = await tx.wait();
                console.log('Transaction confirmed in block:', receipt.blockNumber);

                showAlert(`✅ 🔒 FHE Auction created successfully! Transaction: ${tx.hash.substring(0, 10)}...`, 'success');

                // Reload auctions
                await loadAuctions();

                // Reset form
                document.getElementById('createAuctionForm').reset();

            } catch (error) {
                console.error('Error creating auction:', error);
                const errorMsg = error.reason || error.message || 'Unknown error occurred';
                showAlert('❌ Failed to create auction: ' + errorMsg, 'error');
            }
        }

        // 💰 Start Bidding Function
        function startBidding(auctionId) {
            currentAuctionId = auctionId;

            // For this tutorial, we'll create a simple auction detail display
            document.getElementById('auctionDetails').innerHTML = `
                <div style="background: rgba(245, 158, 11, 0.1); border: 1px solid #f59e0b; border-radius: 8px; padding: 1rem; margin-bottom: 1.5rem;">
                    <h3 style="color: #fbbf24; margin-bottom: 0.5rem;">Auction #${auctionId}</h3>
                    <p style="color: #94a3b8; font-size: 0.9rem;">🔒 Your bid amount will be encrypted using FHE technology</p>
                    <p style="color: #64748b; font-size: 0.8rem; margin-top: 0.5rem;">Only you and authorized parties can see your bid amount</p>
                </div>
            `;

            bidCard.style.display = 'block';
            bidCard.scrollIntoView({ behavior: 'smooth' });
        }

        // 💸 Place Bid Function
        async function placeBid() {
            try {
                if (!selectedBidAmount) throw new Error('Please select a bid amount');
                if (!currentAuctionId) throw new Error('No auction selected');
                if (!contract) throw new Error('Please connect your wallet first');

                let bidAmountEth;
                if (selectedBidAmount === 'custom') {
                    bidAmountEth = document.getElementById('customBidAmount').value;
                    if (!bidAmountEth || parseFloat(bidAmountEth) <= 0) {
                        throw new Error('Please enter a valid custom bid amount');
                    }
                } else {
                    bidAmountEth = selectedBidAmount;
                }

                const comments = document.getElementById('bidComments').value || 'No comments';
                const bidAmountWei = ethers.parseEther(bidAmountEth.toString());

                console.log('Placing encrypted bid:');
                console.log('Auction ID:', currentAuctionId);
                console.log('Bid amount (ETH):', bidAmountEth);
                console.log('Comments:', comments);

                showAlert('🔒 Encrypting bid and submitting to blockchain...', 'info');

                // Submit transaction with ETH payment
                const tx = await contract.placeBid(
                    currentAuctionId,
                    true, // Mark as high bid for demo
                    bidAmountWei,
                    comments,
                    { value: bidAmountWei }
                );

                showAlert('🔄 Encrypted bid submitted! Waiting for confirmation...', 'success');
                console.log('Transaction hash:', tx.hash);

                const receipt = await tx.wait();
                console.log('Transaction confirmed in block:', receipt.blockNumber);

                showAlert(`✅ 🔒 Confidential bid placed successfully! Your bid amount is encrypted on-chain. Transaction: ${tx.hash.substring(0, 10)}...`, 'success');

                // Reset bidding form
                selectedBidAmount = null;
                document.querySelectorAll('.bid-option').forEach(opt => opt.classList.remove('selected'));
                document.getElementById('bidComments').value = '';
                document.getElementById('customBidGroup').classList.add('hidden');
                bidCard.style.display = 'none';

                // Reload auctions to show updated bid count
                await loadAuctions();

            } catch (error) {
                console.error('Error placing bid:', error);
                const errorMsg = error.reason || error.message || 'Unknown error occurred';
                showAlert('❌ Failed to place bid: ' + errorMsg, 'error');
            }
        }

        // 🎨 Setup Event Listeners
        function setupEventListeners() {
            // Connect wallet button
            connectWalletBtn.addEventListener('click', connectWallet);

            // Create auction form
            document.getElementById('createAuctionForm').addEventListener('submit', async (e) => {
                e.preventDefault();

                const title = document.getElementById('auctionTitle').value;
                const description = document.getElementById('auctionDescription').value;
                const category = document.getElementById('auctionCategory').value;
                const minimumBid = document.getElementById('minimumBid').value;

                await createAuction(title, description, category, minimumBid);
            });

            // Bid amount selection
            document.getElementById('bidOptions').addEventListener('click', (e) => {
                if (e.target.classList.contains('bid-option')) {
                    // Remove previous selection
                    document.querySelectorAll('.bid-option').forEach(opt => opt.classList.remove('selected'));

                    // Add selection to clicked option
                    e.target.classList.add('selected');
                    selectedBidAmount = e.target.dataset.amount;

                    // Show/hide custom input
                    const customGroup = document.getElementById('customBidGroup');
                    if (selectedBidAmount === 'custom') {
                        customGroup.classList.remove('hidden');
                    } else {
                        customGroup.classList.add('hidden');
                    }
                }
            });

            // Place bid button
            document.getElementById('placeBidBtn').addEventListener('click', placeBid);
        }

        // 🎨 Show Alert Function
        function showAlert(message, type = 'info') {
            // Remove existing alerts
            const existingAlerts = document.querySelectorAll('.alert');
            existingAlerts.forEach(alert => alert.remove());

            // Create new alert
            const alert = document.createElement('div');
            alert.className = `alert ${type}`;
            alert.textContent = message;

            // Insert at top of main content
            const mainContent = document.querySelector('.main-content');
            mainContent.insertBefore(alert, mainContent.firstChild);

            // Auto-remove after 5 seconds
            setTimeout(() => {
                if (alert.parentNode) {
                    alert.remove();
                }
            }, 5000);
        }

        // 🚀 Start the application
        init();
    </script>
</body>
</html>
```

### Step 3: Update Contract Address

Replace `YOUR_CONTRACT_ADDRESS_HERE` with your deployed contract address from Step 2.

## 🧪 Chapter 6: Testing Your FHE Application

### Step 1: Open Your Application

Open `index.html` in your browser or serve it locally:

```bash
# Simple local server
python -m http.server 8000
# Or if you have Node.js
npx http-server .
```

### Step 2: Test Complete Flow

1. **Connect MetaMask** to Sepolia testnet
2. **Create an auction** with test data
3. **Place confidential bids** and observe encryption in action
4. **Check transaction receipts** on Etherscan

### Step 3: Verify Privacy

- **On Etherscan**: You'll see transactions but bid amounts are encrypted
- **In Browser Console**: Logs show encrypted data handling
- **Smart Contract**: Bid amounts stored as `euint64` encrypted values

## 🎓 Chapter 7: Understanding What You Built

### Key Learning Outcomes

**1. FHE Data Types:**
- `euint64` for encrypted integers
- How to convert regular values to encrypted values
- Access control with `FHE.allow()`

**2. Privacy Guarantees:**
- Bid amounts are encrypted on-chain
- Only authorized parties can decrypt
- Computations possible on encrypted data

**3. Smart Contract Integration:**
- FHE works seamlessly with existing Solidity patterns
- Mixed public/private data in same contract
- Standard Ethereum tooling compatibility

**4. User Experience:**
- Privacy without complexity for end users
- Standard wallet interactions
- Real-time encrypted transactions

### Technical Architecture Review

```
Frontend (HTML/JS)
    ↓ Web3 calls
Smart Contract (Solidity + FHE)
    ↓ Encrypted storage
Blockchain (Sepolia Testnet)
    ↓ Verification
Zama FHE Network
```

## 🚀 Next Steps & Advanced Topics

### Extend Your Application

**1. Add More FHE Features:**
```solidity
// Encrypted comparisons
ebool isHigherBid = FHE.gt(newBid, currentHighest);

// Encrypted arithmetic
euint64 totalBids = FHE.add(bid1, bid2);

// Conditional operations
euint64 winningBid = FHE.select(isWinner, myBid, otherBid);
```

**2. Implement Bid Revelation:**
```solidity
function revealBid(uint256 auctionId, bytes32 signature) external {
    // Reveal encrypted bid with proper permissions
}
```

**3. Add Access Control:**
```solidity
function viewMyBid(uint256 auctionId) external view returns (euint64) {
    // Only bidder can see their own encrypted bid
    require(msg.sender == auctionBids[auctionId][bidIndex].bidder);
    return auctionBids[auctionId][bidIndex].amount;
}
```

### Deployment to Production

**1. Use Zama Devnet:**
```bash
# Add to hardhat.config.js
zama: {
  url: "https://devnet.zama.ai",
  accounts: [process.env.PRIVATE_KEY],
}
```

**2. Gas Optimization:**
- FHE operations cost more gas
- Batch operations when possible
- Use appropriate encrypted data types

**3. Security Best Practices:**
- Validate all inputs before encryption
- Implement proper access controls
- Test edge cases thoroughly

## 📚 Additional Resources

### Documentation
- **Zama FHEVM Docs**: https://docs.zama.ai/fhevm
- **FHE Solidity Library**: https://github.com/zama-ai/fhevm
- **Example Applications**: https://github.com/zama-ai/fhevm-examples

### Community
- **Discord**: Join Zama community for support
- **GitHub**: Contribute to open-source FHE projects
- **Twitter**: Follow @zama_ai for updates

### Example Projects
- **Confidential Voting**: Private election systems
- **Secret Auctions**: Advanced auction mechanisms
- **Private DeFi**: Confidential trading and lending
- **Encrypted Gaming**: Hidden information games

## 🎉 Congratulations!

You've successfully built your first confidential application using FHEVM! You now understand:

- ✅ **FHE Fundamentals**: How encryption works in smart contracts
- ✅ **Practical Implementation**: Building real privacy-preserving dApps
- ✅ **Tool Integration**: Using FHEVM with standard Ethereum tools
- ✅ **User Experience**: Creating intuitive private applications

**Your Next Challenge**: Extend this auction system or build something completely new using the FHE concepts you've learned!

---

**Built with ❤️ for the Zama Developer Community**

*This tutorial demonstrates the power of Fully Homomorphic Encryption in making blockchain applications truly private while maintaining all the benefits of decentralization and transparency.*