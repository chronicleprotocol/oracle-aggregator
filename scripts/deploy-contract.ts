// scripts/deploy.ts
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { IOracleAggregator } from "../typechain-types";

// EXAMPLE usage:
// npx hardhat deploy-contract --contract-name BTC_Oracle_Aggregated_Chronicle_Chainlink_Redstone --network mainnet --check-value-after-deployment

task(
  "deploy-contract",
  "Deploys the given contract without arguments",
  main
).addParam(
  "contractName",
  "Name of the contract"
).addFlag(
  "checkValueAfterDeployment",
  "Set to true if you want to check the oracle value after the deployment"
);

interface Args {
  contractName: string;
  checkValueAfterDeployment: boolean;
}

async function main(args: Args, hre: HardhatRuntimeEnvironment) {
  const { ethers } = hre;

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contract (${args.contractName}) from address: ${deployer.address}`);

  const ContractFactory = await ethers.getContractFactory(args.contractName);

  console.log(`Deployment started`);
  const contract = await ContractFactory.deploy();

  console.log(`Waiting to be deployed`);
  await contract.waitForDeployment();

  const contractAddress = await contract.getAddress();
  console.log("The contract was deployed to:", contractAddress);

  if (args.checkValueAfterDeployment) {
    console.log(`Calling getAggregatedOracleValue`);
    const oracleValue = await (contract as IOracleAggregator).getAggregatedOracleValue();
    console.log({ oracleValue });
  }
}
