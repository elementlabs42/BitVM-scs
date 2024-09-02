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

## Test with Anvil
Start anvil, then run script with sig arg as: 'runTestnet', 'pegOut', 'burnEBTC'
```bash
anvil -f https://mainnet.infura.io/v3/<API_KEY> --fork-block-number <BLOCK_NUM>
forge script script/Deployer.s.sol:Deployer --slow --sig "<FUNCTION_NAME>" --broadcast --rpc-url ${RPC_URL_ANVIL}
```
