import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
// import "@fhevm/hardhat-plugin"; // Will enable after resolving dependency issues
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      metadata: {
        bytecodeHash: "none",
      },
      optimizer: {
        enabled: true,
        runs: 800,
      },
      evmVersion: "cancun",
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      accounts: {
        count: 10,
        accountsBalance: "10000000000000000000000", // 10,000 ETH
      },
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
      gasPrice: 20000000000, // 20 gwei
    },
    // Zama devnet for FHEVM testing (supports full FHE operations)
    zama: {
      url: "https://devnet.zama.ai",
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
      chainId: 8009,
      gasPrice: 1000000000, // 1 gwei for Zama
    },
    // Zama testnet for production FHE testing
    zamaTestnet: {
      url: "https://testnet.zama.ai",
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
      chainId: 8009,
      gasPrice: 1000000000,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY || "",
    },
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6",
    alwaysGenerateOverloads: false,
    externalArtifacts: ["externalArtifacts/*.json"],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
};

export default config;