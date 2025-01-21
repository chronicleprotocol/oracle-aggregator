import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "dotenv/config";
import "./scripts/deploy-contract";

const getForkInfo = () => {
  if (process.env["FORK"]) {
    return {
      forking: { url: process.env["FORK"] },
    };
  }
  return {};
};

const accounts = process.env.PRIVATE_KEY
  ? [process.env.PRIVATE_KEY]
  : undefined;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,
      },
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.MAINNET_ETHERSCAN_API_KEY!,
      base: process.env.BASE_ETHERSCAN_API_KEY!
    },
  },
  networks: {
    hardhat: {
      ...getForkInfo(),
    },
    mainnet: {
      name: "Ethereum Mainnet",
      chainId: 1,
      url: "https://ethereum-rpc.publicnode.com",
      etherScanApi: "https://api.etherscan.io",
      accounts,
    },
    base: {
      name: "Base Mainnet",
      chainId: 8453,
      url: "https://base.publicnode.com",
      accounts,
    },
  },
};

export default config;
