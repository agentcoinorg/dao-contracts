import * as ethers from "ethers";
import fs from "fs";

const NUMBER_OF_PURCHASERS = 100;
const NUMBER_OF_CONTRIBUTORS = 150;

async function main() {
  const purchasers = [];
  for (let i = 0; i < NUMBER_OF_PURCHASERS; i++) {
    const address = ethers.Wallet.createRandom().address;
    const amount = Math.random() * 100 + 1;
    purchasers.push({ address, amount });
  }

  const contributors = [];
  for (let i = 0; i < NUMBER_OF_CONTRIBUTORS; i++) {
    const address = ethers.Wallet.createRandom().address;
    const amount = Math.random() * 100 + 1;
    contributors.push({ address, amount });
  }

  const claimAddresses = {};
  for (const address of purchasers.concat(contributors).map(x => x.address)) {
    claimAddresses[address] = ethers.Wallet.createRandom().address;
  }

  fs.writeFileSync("./test/purchasers.csv", ["Address,Amount"].concat(purchasers.map(x => `${x.address},${x.amount}`)).join("\n"));
  fs.writeFileSync("./test/contributors.csv", ["Address,Amount"].concat(contributors.map(x => `${x.address},${x.amount}`)).join("\n"));
  fs.writeFileSync("./test/claim-addresses.csv", ["Old address,New address"].concat(Object.keys(claimAddresses).map(x => `${x},${claimAddresses[x]}`)).join("\n"));
}

main().then(() => process.exit(0));