# oracle-aggregator

## Deployment instructions

Firstly, prepare your `.env` file based on the `sample.env` file. The run the following commans:

```sh
# Compile contracts
yarn compile

# Run tests
yarn test

# Dry-run deployment on fork (replace params depending on your contract and network RPC)
FORK=https://ethereum-rpc.publicnode.com npx hardhat --network hardhat deploy-contract --contract-name BTC_Oracle_Aggregated_Chronicle_Chainlink_Redstone --check-value-after-deployment

# Deploy (replace params depending on your contract and network)
npx hardhat deploy-contract --contract-name BTC_Oracle_Aggregated_Chronicle_Chainlink_Redstone --network mainnet --check-value-after-deployment

# Submit source code to blockchain explorer (e.g. etherscan)
npx hardhat verify <CONTRACT_ADDRESS> --network mainnet
```
