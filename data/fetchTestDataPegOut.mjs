import fs from 'fs'
import assert from 'assert'
import { DEFAULT_STEP, DEFAULT_BLOCK_COUNT, TEST_DATA_FILE, SHARED_DATA } from './lib/helper.mjs'
import { initializaeTestData, processProofInfo, processBlockInfos } from './lib/helper.mjs'
import { getProvider } from './lib/provider.mjs'
import { reverseBytesNArray, BLOCK_HEADER_BYTES, EPOCH_BLOCK_COUNT } from './lib/coder.mjs'
import { getBlockInfoByHeight, getTransactionInfo } from './lib/api.mjs'

  // usage: `node script/fetchTestDataPegOut.mjs <provider> <txId>`
  ; (async () => {
    const providerId = parseInt(process.argv[2])
    const provider = getProvider(providerId)
    const txId = process.argv[3].toString()
    const _proofInfo = await getTransactionInfo(provider, txId)

    const initialHeight = (Math.floor(_proofInfo.status.block_height / DEFAULT_STEP) - 1) * DEFAULT_STEP
    const start = initialHeight + 1
    const end = Math.ceil((_proofInfo.status.block_height + DEFAULT_BLOCK_COUNT) / DEFAULT_STEP) * DEFAULT_STEP
    const headerCount = end - initialHeight
    console.log(`>>> fetching ${headerCount} blocks from ${start} to ${end}`)
    const blocksfile = `blocks-${providerId}-${start}-${end}.json`
    const proofFile = `proof-${providerId}-${DEFAULT_STEP}_${initialHeight}-${txId.substring(0, 6)}.json`

    const blockResult = await processBlockInfos(blocksfile, provider, initialHeight, end)
    const headersString = blockResult.headers.slice(1).join('')
    assert(headersString.length === BLOCK_HEADER_BYTES * 2 * (end - start + 1))

    const proofResult = await processProofInfo(proofFile, provider, txId, initialHeight)

    let testData
    if (fs.existsSync(TEST_DATA_FILE)) {
      testData = JSON.parse(fs.readFileSync(TEST_DATA_FILE, 'utf-8'))
    } else {
      testData = initializaeTestData()
    }
    const epochStartHeight = Math.floor(blockResult.blockInfos[0].height / EPOCH_BLOCK_COUNT) * EPOCH_BLOCK_COUNT
    const epochStartBlock = await getBlockInfoByHeight(provider, epochStartHeight)
    testData.pegOut.storage.submit = [{ headers: `0x${headersString}` }]
    testData.pegOut.storage.constrcutor = {
      step: DEFAULT_STEP,
      height: blockResult.blockInfos[0].height,
      hash: `0x${blockResult.blockInfos[0].id}`,
      timestamp: blockResult.blockInfos[0].timestamp,
      bits: blockResult.blockInfos[0].bits,
      epochTimestamp: epochStartBlock.timestamp,
    }

    testData.pegOut.verification.proof = {
      merkleProof: `0x${reverseBytesNArray(proofResult.merkleProof.merkle.join(''), 32)}`,
      parents: `0x${proofResult.parents.join('')}`,
      children: `0x${proofResult.children.join('')}`,
      index: proofResult.proofInfo.block_index,
      blockHeight: proofResult.proofInfo.self.height,
      blockHeader: `0x${proofResult.header}`,
      rawTx: `0x${proofResult.rawTx}`,
    }

    testData.pegOut.withdrawer = SHARED_DATA.withdrawerEvmAddress
    testData.pegOut.pegOutTimestamp = SHARED_DATA.pegOutTimestamp
    testData.pegOut.amount = SHARED_DATA.pegOutValue
    testData.pegOut.withdrawerPubKey = SHARED_DATA.withdrawerPubKey
    testData.pegOut.operatorPubKey = SHARED_DATA.operatorPubKey
    testData.pegOut.nOfNPubKey = SHARED_DATA.nOfNPubKey
    fs.writeFileSync(TEST_DATA_FILE, JSON.stringify(testData, null, 2) + '\n')

    console.log('>>> DONE')
  })()
