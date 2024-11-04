# Agentcoin Token
## Token Details
- Name: Agentcoin Token
- Symbol: AGENT
- Decimals: 18
- Total Supply: 1,000,000,000 AGENT

Agentcoin Token is an ERC20 token with snapshot capabilities. The token is upgradable and owned by the DAO's address.

## Test deployment

- Agentcoin Token contract address: 0xCa7d0393aD19C05cbAeC7c6f5505b7B3FDea35Bc (Proxy)
- Agentcoin Token implementation address: 0xfD70ef2AEdFF0112A5bC78502A8F57564626B292
- Owner and Holder address: 0xF6fB693BB196AE5f5dEB98D502c52B8C31025f5D (Gnosis Safe)

## Getting started
### Dependencies
- Node.js
- Yarn
- Foundry

To install Foundry follow the steps at https://book.getfoundry.sh/getting-started/installation

## Deployment Process
### Sepolia

#### Instructions
Open the terminal in the `./contracts` directory.
Create a `.env` file with the following the example at `.env.example`.
To deploy on sepolia run the `./deploy/sepolia.sh` script.
The script can be used with either a forge account or a private key.

- To deploy with the forge account, before running the script, set the `FORGE_ACCOUNT` environment variable to the forge account address.
- To deploy with a private key, run the `./deploy/sepolia.sh` script with the `pk` argument like so:
```bash
./deploy/sepolia.sh pk
```
The script will prompt you to enter the private key.

## Allocations
- 10,000 AGENT for 1 WRAP-IOU for all purchasers
- 10,000 AGENT for 1 WRAP-IOU for all contributors who've voted in more than one proposal
- Remaining supply (1B total supply) minted to the agentcoin treasury address (mainnet: 0x8c3FA50473065f1D90f186cA8ba1Aa76Aee409Bb)
- All allocated AGENT (except treasury allocation) will be put into vesting contracts. These vesting contracts should have a 12 month cliff and 24 month vesting thereafter. 1/3 available for withdrawal after 12 months.

Allocation scripts are in the `./allocations` directory.
To get started, open the `./allocations` directory in the terminal and run the following commands:

```bash
yarn install
```

### Testing
To generate test and run the allocation script, run the following command:

```bash
yarn test
```
Under the hood, the test script runs the following commands:
```bash
node generate-test-data.js
node generate-allocations.js test
```
Results will be saved in the `./allocations/test` directory.
There you can inspect and verify the data as well as the results.

### Generating production allocations
To generate production allocations, run the following command:

```bash
yarn prod
```
This will generate the production allocations in the `./allocations/prod` directory.
