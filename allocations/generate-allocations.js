import fs from "fs";
import * as ethers from "ethers";

const AGENT_PER_WRAP = 10_000;
const VESTING_START_DATE = "2024-11-13"

async function main() {
  if (process.argv.length < 3) {
    console.error("Usage: node generate-allocations.js test|prod");
    process.exit(1);
  }

  const mode = process.argv[2];
  if (mode !== "test" && mode !== "prod") {
    console.error("Usage: node generate-allocations.js test|prod");
    process.exit(1);
  }

  const purchasersData = fs.readFileSync(`./${mode}/purchasers.csv`, "utf8");
  const contributorsData = fs.readFileSync(`./${mode}/contributors.csv`, "utf8");
  const claimAddressesData = fs.readFileSync(`./${mode}/claim-addresses.csv`, "utf8");

  const purchasers = purchasersData
    .split("\n")
    .slice(1)
    .map(x => {
      const [address, amount] = x.split(",");
      return { address, amount };
    });

  for (const { address } of purchasers) {
    if (!ethers.isAddress(address)) {
      throw new Error(`Invalid purchaser address: ${address}`);
    }
  }

  const contributors = contributorsData
    .split("\n")
    .slice(1)
    .map(x => {
      const [address, amount] = x.split(",");
      return { address, amount };
    });

  for (const { address } of contributors) {
    if (!ethers.isAddress(address)) {
      throw new Error(`Invalid contributor address: ${address}`);
    }
  }

  const claimAddresses = claimAddressesData
    .split("\n")
    .slice(1)
    .map(x => {
      const [oldAddress, newAddress] = x.split(",");
      return { oldAddress, newAddress };
    }).reduce((acc, x) => {
      acc[x.oldAddress] = x.newAddress;
      return acc;
    }, {});

  const all = purchasers.concat(contributors).map(x => {
    const claimAddress = claimAddresses[x.address];

    if (!claimAddress) {
      throw new Error(`Claim address not found for address ${x.address}`);
    }

    if (!ethers.isAddress(claimAddress)) {
      throw new Error(`Invalid claim address: ${claimAddress} for address ${x.address}`);
    }

    return {
      address: x.address,
      amount: parseFloat(x.amount) * AGENT_PER_WRAP,
      claimAddress: claimAddress
    };
  });
  
  const allocations = [
    "Recipient address,Amount of tokens,Vesting start date"
  ].concat(all.map(x => {
    return `${x.claimAddress},${x.amount},${VESTING_START_DATE}`;
  })).join("\n");

  fs.writeFileSync(`./${mode}/allocations.csv`, allocations);
  
  const totalAmount = all.reduce((acc, x) => acc + x.amount, 0);
  console.log(`Total AITV amount: ${totalAmount}`);
}

main().then(() => process.exit(0));