import 'dotenv/config';
import fs from 'fs';
import path from 'path';
import { parse } from 'csv-parse/sync';
import { ethers } from 'ethers';

export const MAX_BENEFICIARIES_PER_TX = 100 as const;

const proc: any = (globalThis as any).process;

type RecordRow = {
  address: string;
  amount?: string;
  allocation?: string;
};

type CsvRow = { address: string; amount: bigint };

type CliOptions = {
  dryRun: boolean;
  batchSize: number;
  noCheck: boolean;
  concurrency: number;
};

const ALLOWED_FLAGS = new Set(['dry-run', 'batch', 'no-check', 'concurrency']);

const ABI = [
  {
    inputs: [
      { internalType: 'address[]', name: '_users', type: 'address[]' },
      { internalType: 'uint256[]', name: '_amounts', type: 'uint256[]' },
    ],
    name: 'registerBeneficiaries',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: '', type: 'address' },
    ],
    name: 'beneficiaries',
    outputs: [
      { internalType: 'uint256', name: 'allocation', type: 'uint256' },
      { internalType: 'uint256', name: 'startTime', type: 'uint256' },
      { internalType: 'uint256', name: 'claimedAmount', type: 'uint256' },
      { internalType: 'uint8', name: 'claimType', type: 'uint8' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

function getEnv(name: string, required = true): string | undefined {
  const value = proc?.env?.[name];
  if (!value && required) {
    throw new Error(`Missing required env var ${name}`);
  }
  return value;
}

function usageAndExit(message?: string): never {
  if (message) console.error(message);
  console.error('Usage: airdrop-register [--batch N] [--dry-run] [--no-check] [--concurrency N]');
  proc?.exit?.(1);
  // satisfies never
  throw new Error('exit');
}

function parseArgs(argv: string[]) {
  const args: Record<string, string | boolean> = {};
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith('--')) {
      const key = arg.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith('--')) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    }
  }
  return args;
}

function parseCliOptions(argv: string[]): CliOptions {
  const args = parseArgs(argv);
  const unknown = Object.keys(args).filter((k) => !ALLOWED_FLAGS.has(k));
  if (unknown.length) usageAndExit(`Unknown option(s): ${unknown.join(', ')}`);

  if (args['concurrency'] === true) usageAndExit('Invalid --concurrency: expected a positive integer');
  let concurrency = 10;
  if (typeof args['concurrency'] === 'string') {
    const n = Number(args['concurrency']);
    if (!Number.isInteger(n) || n <= 0) usageAndExit('Invalid --concurrency: expected a positive integer');
    concurrency = n;
  }

  return {
    dryRun: Boolean(args['dry-run']),
    batchSize: resolveBatchSize(args['batch']),
    noCheck: Boolean(args['no-check']),
    concurrency,
  };
}

function chunkArray<T>(items: T[], chunkSize: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += chunkSize) {
    chunks.push(items.slice(i, i + chunkSize));
  }
  return chunks;
}

function resolveBatchSize(argvValue?: string | boolean): number {
  const envBatch = process.env.BATCH_SIZE;
  if (argvValue === true) usageAndExit('Invalid --batch: expected a positive integer');
  const fromArg = typeof argvValue === 'string' ? Number(argvValue) : undefined;
  const requested = fromArg ?? (envBatch ? Number(envBatch) : MAX_BENEFICIARIES_PER_TX);
  if (!Number.isInteger(requested) || requested <= 0) usageAndExit('Invalid batch size; expected positive integer');
  return Math.min(requested, MAX_BENEFICIARIES_PER_TX);
}

async function mapWithConcurrency<I, O>(items: I[], limit: number, fn: (item: I, index: number) => Promise<O>): Promise<O[]> {
  const results: O[] = new Array(items.length);
  let idx = 0;
  const workers: Promise<void>[] = [];
  const run = async () => {
    while (idx < items.length) {
      const cur = idx++;
      results[cur] = await fn(items[cur], cur);
    }
  };
  const workerCount = Math.max(1, limit);
  for (let i = 0; i < workerCount; i++) workers.push(run());
  await Promise.all(workers);
  return results;
}

function normalizeAddress(value: string): string {
  try {
    return ethers.getAddress(value.trim());
  } catch {
    throw new Error(`Invalid address: ${value}`);
  }
}

function toAmountWei(value: string, decimals: number): bigint {
  const v = value.trim();
  if (v === '') throw new Error('Empty amount');
  // If contains a decimal point, treat as human-readable units
  return ethers.parseUnits(v, decimals);
}

function getPackageDir(): string {
  return path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
}

function getDefaultCsvPath(): string {
  return path.resolve(getPackageDir(), 'beneficiaries.csv');
}

function loadAndValidateCsv(filePath: string): CsvRow[] {
  const csvText = fs.readFileSync(filePath, 'utf8');
  const records = parse(csvText, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  }) as RecordRow[];
  if (!records.length) throw new Error('No records found.');
  const rows = records.map((r, idx) => {
    const rawAddress = r.address ?? '';
    const rawAmount = r.amount ?? r.allocation ?? '';
    if (!rawAddress) throw new Error(`Row ${idx + 1}: missing address`);
    if (!rawAmount) throw new Error(`Row ${idx + 1}: missing amount/allocation`);
    const address = normalizeAddress(rawAddress);
    const amount = toAmountWei(String(rawAmount), 18);
    return { address, amount };
  });
  return rows;
}

function createClients(rpcUrl: string, privateKey: string, contractAddress: string) {
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);
  const contract = new ethers.Contract(contractAddress, ABI, wallet);
  return { provider, wallet, contract };
}

async function filterAlreadyRegistered(contract: ethers.Contract, rows: CsvRow[], concurrency: number): Promise<CsvRow[]> {
  const allocations = await mapWithConcurrency(rows, concurrency, async (r) => {
    try {
      const b = await contract.beneficiaries(r.address);
      return (b?.allocation ?? 0n) as bigint;
    } catch {
      return 0n;
    }
  });
  const filtered: CsvRow[] = [];
  for (let i = 0; i < rows.length; i++) {
    if (allocations[i] === 0n) filtered.push(rows[i]);
  }
  return filtered;
}

async function estimateThenSend(contract: ethers.Contract, users: string[], amounts: bigint[]) {
  try {
    const gas = await contract.registerBeneficiaries.estimateGas(users, amounts);
    console.log(`  Estimated gas: ${gas.toString()}`);
  } catch {
    console.log('  Gas estimation failed; continuing...');
  }
  const tx = await contract.registerBeneficiaries(users, amounts);
  console.log(`  Sent tx: ${tx.hash}`);
  const receipt = await tx.wait();
  console.log(`  Confirmed in block ${receipt.blockNumber} (gas used ${receipt.gasUsed})`);
  return { hash: tx.hash as string, blockNumber: Number(receipt.blockNumber) };
}

async function main() {
  const { dryRun, batchSize, noCheck, concurrency } = parseCliOptions(process.argv);

  // Default CSV path: airdrop/beneficiaries.csv (relative to this package dir)
  const filePath = getDefaultCsvPath();
  if (!fs.existsSync(filePath)) usageAndExit(`File not found: ${filePath}`);

  const rpcUrl = getEnv('RPC_URL')!;
  const privateKey = getEnv('PRIVATE_KEY')!;
  const contractAddress = getEnv('CONTRACT_ADDRESS')!;
  const expectedChainId = proc?.env?.CHAIN_ID ? BigInt(proc.env.CHAIN_ID) : undefined;

  const csvText = fs.readFileSync(filePath, 'utf8');
  let rows = loadAndValidateCsv(filePath);

  console.log(`Loaded ${rows.length} records from ${filePath}`);
  console.log(`Using batch size ${batchSize} (cap ${MAX_BENEFICIARIES_PER_TX}), decimals 18`);

  if (dryRun) {
    console.log('[Dry-run] First 3 rows preview:', rows.slice(0, 3));
    return;
  }

  const { provider, contract } = createClients(rpcUrl, privateKey, contractAddress);
  const network = await provider.getNetwork();
  console.log(`Connected to chainId ${network.chainId}`);
  if (expectedChainId !== undefined && network.chainId !== expectedChainId) {
    throw new Error(`CHAIN_ID mismatch: expected ${expectedChainId}, got ${network.chainId}`);
  }

  // Determine which rows still need registration (on-chain filter makes this idempotent across runs)
  let remaining = rows;
  if (!noCheck) {
    console.log(`Verifying ${remaining.length} address(es) on-chain to skip already registered (concurrency ${concurrency})...`);
    remaining = await filterAlreadyRegistered(contract, remaining, concurrency);
  }

  if (remaining.length === 0) {
    console.log('Nothing to do: all beneficiaries in CSV are already registered.');
    return;
  }

  const batches = chunkArray(remaining, batchSize);
  console.log(`Submitting ${batches.length} transaction(s)`);

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    const users = batch.map((r) => r.address);
    const amounts = batch.map((r) => r.amount);

    console.log(`Batch ${i + 1}/${batches.length}: ${users.length} beneficiaries`);
    try {
      await estimateThenSend(contract, users, amounts);
    } catch (err: any) {
      console.error(`Batch ${i + 1} failed:`, err?.reason || err?.message || err);
      throw err;
    }
  }

  console.log('All batches submitted successfully.');
}

main().catch((err) => {
  console.error(err);
  proc?.exit?.(1);
});


