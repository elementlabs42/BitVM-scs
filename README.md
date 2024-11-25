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

source .env
forge script script/Test.s.sol:End2End --slow --sig "<FUNCTION_NAME>" --broadcast --rpc-url ${RPC_URL_ANVIL}
```

## Test for UI
1. Start Anvil forking mainnet, use anvil dev account private keys for PRIVATE_KEY_0 and PRIVATE_KEY_1 in .env

2. run script TestForUI.s.sol to deploy bridge and eBtc<br>
*Try removing cache file if deployment fails*

```bash
anvil --chain-id <CHAIN_ID> --state <CACHE_FILE_PATH> -f https://mainnet.infura.io/v3/<API_KEY>

source .env
forge script script/TestForUI.s.sol:End2End --broadcast --rpc-url ${RPC_URL_ANVIL}
```

3. Use bridge and ebtc addresses from Deployments.json in UI
4. Add a custom network in wallet
5. Test on UI<br>
*May need 'Clear activity tab data' in settings/advaced to reset nonce*
