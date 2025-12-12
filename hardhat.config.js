require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// Validate private key format
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const accounts = PRIVATE_KEY && PRIVATE_KEY.startsWith('0x') && PRIVATE_KEY.length === 66
  ? [PRIVATE_KEY]
  : [];

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    base: {
      url: process.env.BASE_MAINNET_RPC_URL || "https://mainnet.base.org",
      accounts: accounts,
      chainId: 8453,
    },
    "base-sepolia": {
      url: "https://sepolia.base.org",
      accounts: accounts,
      chainId: 84532,
    },
    celo: {
      url: process.env.CELO_MAINNET_RPC_URL || "https://forno.celo.org",
      accounts: accounts,
      chainId: 42220,
    },
    "celo-alfajores": {
      url: "https://alfajores-forno.celo-testnet.org",
      accounts: accounts,
      chainId: 44787,
    },
  },
  etherscan: {
    apiKey: {
      base: process.env.BASESCAN_API_KEY || "",
      celo: process.env.CELOSCAN_API_KEY || "",
      "celo-alfajores": process.env.CELOSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      },
      {
        network: "celo",
        chainId: 42220,
        urls: {
          apiURL: "https://api.celoscan.io/api",
          browserURL: "https://celoscan.io"
        }
      },
      {
        network: "celo-alfajores",
        chainId: 44787,
        urls: {
          apiURL: "https://api-alfajores.celoscan.io/api",
          browserURL: "https://alfajores.celoscan.io"
        }
      }
    ]
  },
  sourcify: {
    enabled: false
  }
};
