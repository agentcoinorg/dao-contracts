#!/bin/bash
# This script manually compiles legacy Vyper contracts.
# Exit immediately if a command exits with a non-zero status.
set -e

echo "--- Compiling Legacy Vyper Contracts ---"

# Create the artifact directory
mkdir -p vyper-out/VotingEscrow.vy

# Compile the contract
vyper -f combined_json lib/curve-dao-contracts/contracts/VotingEscrow.vy > vyper-out/VotingEscrow.vy/VotingEscrow.vy.json

echo "Success: VotingEscrow.vy compiled."