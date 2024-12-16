if [[ $1 = "pk" ]]; then
    export $(cat .env | xargs) && \
    forge script ./script/DeployAgentcoinTvToken.s.sol \
        --rpc-url $SEPOLIA_RPC_URL \
        --broadcast \
        -g 200 \
        --force \
        --verify \
        --verifier-url https://api-sepolia.etherscan.io/api \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --interactives 1 \
        --slow
else
    export $(cat .env | xargs) && \
    forge script ./script/DeployAgentcoinTvToken.s.sol \
        --rpc-url $SEPOLIA_RPC_URL \
        --broadcast \
        -g 200 \
        --force \
        --verify \
        --verifier-url https://api-sepolia.etherscan.io/api \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --account $FORGE_ACCOUNT \
        --slow
fi