import fs from 'fs'
import assert from 'assert'
import { DEFAULT_STEP, DEFAULT_BLOCK_COUNT, TEST_DATA_FILE } from './lib/helper.mjs'
import { initializaeTestData, processProofInfo, processBlockInfos } from './lib/helper.mjs'
import { getProvider } from './lib/provider.mjs'
import { reverseBytesNArray, BLOCK_HEADER_BYTES, EPOCH_BLOCK_COUNT } from './lib/coder.mjs'
import { getBlockInfoByHeight, getTransactionInfo } from './lib/api.mjs'

  // usage: `node script/fetchTestDataPegIn.mjs <provider> <depositTxId> <confirmTxId>`
  ; (async () => {
    const providerId = parseInt(process.argv[2])
    const provider = getProvider(providerId)
    const txId1 = process.argv[3].toString()
    const txId2 = process.argv[4].toString()
    const _proofInfo1 = await getTransactionInfo(provider, txId1)
    const _proofInfo2 = await getTransactionInfo(provider, txId2)
    if (_proofInfo1.status.block_height > _proofInfo2.status.block_height) {
      throw new Error(`deposit block height higher than confirm: ${_proofInfo1.status.block_height} > ${_proofInfo2.status.block_height}`)
    }
    const initialHeight = (Math.floor(_proofInfo1.status.block_height / DEFAULT_STEP) - 1) * DEFAULT_STEP
    const start = initialHeight + 1
    const end = Math.ceil((_proofInfo2.status.block_height + DEFAULT_BLOCK_COUNT) / DEFAULT_STEP) * DEFAULT_STEP
    const headerCount = end - initialHeight
    console.log(`>>> fetching ${headerCount} blocks from ${start} to ${end}`)
    const blocksfile = `blocks-${providerId}-${start}-${end}.json`
    const proof1file = `proof-${providerId}-${DEFAULT_STEP}_${initialHeight}-${txId1.substring(0, 6)}.json`
    const proof2file = `proof-${providerId}-${DEFAULT_STEP}_${initialHeight}-${txId2.substring(0, 6)}.json`

    const blockResult = await processBlockInfos(blocksfile, provider, initialHeight, end)
    const headersString = blockResult.headers.slice(1).join('')
    assert(headersString.length === BLOCK_HEADER_BYTES * 2 * (end - start + 1))

    const proof1Result = await processProofInfo(proof1file, provider, txId1, initialHeight)
    const proof2Result = await processProofInfo(proof2file, provider, txId2, initialHeight)

    let testData
    if (fs.existsSync(TEST_DATA_FILE)) {
      testData = JSON.parse(fs.readFileSync(TEST_DATA_FILE, 'utf-8'))
    } else {
      testData = initializaeTestData()
    }
    const epochStartHeight = Math.floor(blockResult.blockInfos[0].height / EPOCH_BLOCK_COUNT) * EPOCH_BLOCK_COUNT
    const epochStartBlock = await getBlockInfoByHeight(provider, epochStartHeight)
    testData.pegIn.storage.submit = [{ headers: headersString }]
    testData.pegIn.storage.constrcutor = {
      step: DEFAULT_STEP,
      height: blockResult.blockInfos[0].height,
      hash: blockResult.blockInfos[0].id,
      timestamp: blockResult.blockInfos[0].timestamp,
      bits: blockResult.blockInfos[0].bits,
      epochTimestamp: epochStartBlock.timestamp,
    }

    testData.pegIn.verification.proof1 = {
      merkleProof: reverseBytesNArray(proof1Result.merkleProof.merkle.join(''), 32),
      parents: proof1Result.parents.join(''),
      children: proof1Result.children.join(''),
      index: proof1Result.proofInfo.block_index,
      blockHeight: proof1Result.proofInfo.self.height,
      blockHeader: proof1Result.header,
      rawTx: proof1Result.rawTx,
    }
    testData.pegIn.verification.proof2 = {
      merkleProof: reverseBytesNArray(proof2Result.merkleProof.merkle.join(''), 32),
      parents: proof2Result.parents.join(''),
      children: proof2Result.children.join(''),
      index: proof2Result.proofInfo.block_index,
      blockHeight: proof2Result.proofInfo.self.height,
      blockHeader: proof2Result.header,
      rawTx: proof2Result.rawTx,
    }
    fs.writeFileSync(TEST_DATA_FILE, JSON.stringify(testData, null, 2) + '\n')

    console.log('>>> DONE')
  })()
