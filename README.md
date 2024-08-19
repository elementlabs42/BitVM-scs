# BitVM Bridge

## Build
```bash
forge build
```

## Run Test
```bash
forge test -vv
```

## Test with given transaction ids
```bash
node script/fetchTestDataPegIn.mjs <provider> <depositTxId> <confirmTxId>
node script/fetchTestDataPegOut.mjs <provider> <txId>
forge test -vv --match-test testPegIn_pegIn_file
forge test -vv --match-test testPegOut_pegOut_file
```

## Deploy script
```bash
source .env
forge script deploy/Deployer.s.sol:Deployer --broadcast --verify --rpc-url <${RPC_URL_SEPOLIA} | ${RPC_URL_MAINNET}>
```

## Deploy script with BT Testnet support
```bash
source .env
forge script deploy/Deployer.s.sol:Deployer --sig "testnet()" --broadcast --verify --rpc-url <${RPC_URL_SEPOLIA} | ${RPC_URL_MAINNET}>
```
