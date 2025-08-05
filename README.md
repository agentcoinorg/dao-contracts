# AITV Token
## Token Details
- Name: AITV
- Symbol: AITV
- Decimals: 18
- Total Supply: 1,000,000,000 AITV

AITV Token is an ERC20 token with snapshot capabilities. The token is upgradable and owned by the DAO's address.

# Ethereum (mainnet) deployment
- AITV Token contract address: 0x04E69Ff14A86E1ca9a155A8563E95887973EE175 (Proxy)
- AITV Token implementation address: 0x5bcdE98A19D7dCa9c401b83D5450176e3459b698
- Owner address: 0xeff5440746A7B362273ca7CDDB9CD5783C71737D (Gnosis Safe)

## Test deployment

- Agentcoin TV Token contract address: 0xCa7d0393aD19C05cbAeC7c6f5505b7B3FDea35Bc (Proxy)
- Agentcoin TV Token implementation address: 0xfD70ef2AEdFF0112A5bC78502A8F57564626B292
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
- 10,000 AITV for 1 WRAP-IOU for all purchasers
- 10,000 AITV for 1 WRAP-IOU for all contributors who've voted in more than one proposal
- Remaining supply (1B total supply) minted to the aitv treasury address (mainnet: 0x8c3FA50473065f1D90f186cA8ba1Aa76Aee409Bb)
- All allocated AITV (except treasury allocation) will be put into vesting contracts. These vesting contracts should have a 12 month cliff and 24 month vesting thereafter. 1/3 available for withdrawal after 12 months.

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

# Airdrop and Vesting System

The AITV ecosystem includes a flexible vesting and airdrop system to manage token distributions. This system is designed to reward both short-term participants and long-term supporters who wish to engage in governance. It is primarily composed of two smart contracts: `AITVAirdropVesting.sol` and `VotingEscrow.vy`.

***Note**: The `AITVAirdropVesting` contract described below is designed for specific airdrop campaigns with a 90-day vesting schedule.

## `AITVAirdropVesting.sol`

This contract manages the vesting schedule for specific airdrop beneficiaries. The project owner registers a list of eligible addresses and their token allocations. Once registered, a beneficiary has a one-time choice between two methods for claiming their tokens.

### Vesting Schedule

*   **Immediate Unlock**: **5%** of the total allocation is unlocked instantly upon registration.
*   **Linear Vesting**: The remaining **95%** vests linearly over **90 days**.

### User Actions (One-Time Choice)

A beneficiary can only execute **one** of the following functions. Once a choice is made, their airdrop is considered fully claimed.

#### 1. Standard Claim: `claimAndForfeitRemaining()`

This is the standard option to claim vested tokens.

*   **Functionality**: Calculates the total vested amount (initial 5% + linearly vested portion) and transfers it to the user.
*   **Forfeiture Clause**: Any tokens that have not yet vested at the moment of the claim are **permanently forfeited** and sent to the treasury. To receive the full 100%, a user must wait for the full 90-day vesting period to complete before calling this function.
*   **Use Case**: Ideal for users who want liquid tokens without a long-term commitment.

#### 2. Stake for Full Allocation: `claimAndDepositToLock()`

This option allows a user to bypass the vesting schedule by staking their **entire 100% allocation** into the governance system.

*   **Prerequisites**:
    1.  The user must already have an active lock in the `VotingEscrow` contract.
    2.  The existing lock's end date must be at least **90 days** in the future.
    3.  The user must have pre-approved the `VotingEscrow` contract to spend their AITV tokens. This requires a separate ERC20 `approve` transaction.
*   **Functionality**: The contract validates the user's lock, transfers the full 100% allocation to them, and immediately calls the `VotingEscrow` contract to deposit those tokens into the user's existing lock, boosting their voting power.
*   **Use Case**: Perfect for long-term supporters who want to maximize their governance influence immediately.

## `VotingEscrow.vy`

This is a vote-escrow contract based on the widely-used Curve DAO model.
To build the contract, run `./build-vyper.sh` in the `contracts` directory. This will compile the Vyper contract and generate the necessary artifacts.
Building the contract requires Vyper and Python 3.8 to be installed.

### Core Function

Users lock their `AITV` tokens for a chosen duration to receive `veAITV` (vote-escrowed AITV). `veAITV` is non-transferable and represents a user's voting power in the DAO. The longer the lock, the more voting power is granted per `AITV` token.

### Interaction with the Airdrop Contract

The `VotingEscrow` contract works with the `AITVAirdropVesting` contract to enable the "Stake for Full Allocation" feature. `AITVAirdropVesting` checks a user's lock status (`locked`) in `VotingEscrow` and then uses the `deposit_for` function to add the airdropped tokens to the user's stake.