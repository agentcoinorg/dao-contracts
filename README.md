https://forum.polywrap.io/t/important-proposal-critical-steps-for-deployment-of-agent-token/482

TODOs (Deadline November 13th):
* Create AGENT token ready to deploy on mainnet (Name = Agentcoin Token; Ticker = AGENT; Decimals = 18; Supply = 1 Billion)
  * AGENT token contract should be upgradable and owned by the DAO's address.
  * AGENT token should be ERC20Snapshot
  * Upgradeability should be able to be turned off completely in the future
* Allocation is as follows:
  * 10,000 AGENT for 1 WRAP-IOU for all purchasers
  * 10,000 AGENT for 1 WRAP-IOU for all contributors who've voted in more than one proposal
  * To do this, we should rely upon 2 JSON files in the repo, with lists of addresses for both of these token holder categories (purchaser & contributor)
  * Mint remaining supply (1B total supply) to the agentcoin treasury address (mainnet: 0x8c3FA50473065f1D90f186cA8ba1Aa76Aee409Bb)
* Designation of New Addresses - support a "claimAddress.json" file which maps an old address to a new address.
* All allocated AGENT (except treasury allocation) will be put into vesting contracts. These vesting contracts should have a 12 month cliff and 24 month vesting thereafter. 1/3 available for withdrawal after 12 months.
* Update new signers + make sure they have good opsec
* Setup Snapshot X
  * SnapshotX parameters: 7.5% quorum, 0 vote delay, 3 day min voting period, 7 day max voting period
  * Able to vote with AGENT and locked AGENT
  * Add snapshotX to multi-sig
* Deployment process should be detailed in the README for anyone to follow
* We need to document how SnapshotX voters can create specific types of transactions
  * 1. creating a new token package for a new contributor
  * 2. revoking a token package for a contributor that has left
