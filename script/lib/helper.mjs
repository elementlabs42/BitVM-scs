import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { getTransactionHex, getTransactionMerkleProof, getParentsAndChildrenHashes, getProofTxnBlockHeader } from './api.mjs'
import { getBlockInfos, getBlockHeaders, getTransactionInfo } from './api.mjs'

export const DEFAULT_STEP = 10
export const DEFAULT_BLOCK_COUNT = 10

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DATA_SAMPLE_FILE = path.join(__dirname, '../../test/fixture/test-data.sample.json')
export const TEST_DATA_FILE = path.join(__dirname, '../../test/fixture/test-data.json')

export const SHARED_DATA = {
  withdrawerEvmAddress: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
  pegOutValue: 131072,
  pegOutTimestamp: 1722328130,
}

export function initializaeTestData() {
  return JSON.parse(fs.readFileSync(TEST_DATA_SAMPLE_FILE, 'utf-8'))
}

export async function processProofInfo(proofInfoFile, provider, txId1, initialHeight) {
  let proofInfo
  if (fs.existsSync(proofInfoFile)) {
    console.log(`>>> reading ${proofInfoFile}`)
    proofInfo = JSON.parse(fs.readFileSync(proofInfoFile, 'utf-8'))
  } else {
    proofInfo = await getTransactionInfo(provider, txId1)
    proofInfo.step = DEFAULT_STEP
    proofInfo.initial_height = initialHeight
  }
  if (proofInfo.status.block_height < initialHeight) {
    throw new Error(`block height lower than initialHeight: ${proofInfo.status.block_height} < ${initialHeight}`)
  }
  const rawTx = await getTransactionHex(provider, proofInfo)
  const merkleProof = await getTransactionMerkleProof(provider, proofInfo)
  const { parents, children } = await getParentsAndChildrenHashes(provider, proofInfo)
  const header = await getProofTxnBlockHeader(provider, proofInfo)
  fs.writeFileSync(proofInfoFile, JSON.stringify(proofInfo, null, 2) + '\n')

  return { proofInfo, rawTx, merkleProof, parents, children, header }
}

export async function processBlockInfos(blocksFile, provider, initialHeight, end) {
  let blockInfos
  if (fs.existsSync(blocksFile)) {
    console.log(`>>> reading ${blocksFile}`)
    blockInfos = JSON.parse(fs.readFileSync(blocksFile, 'utf-8'))
  } else {
    blockInfos = await getBlockInfos(provider, initialHeight, end)
  }
  const headers = await getBlockHeaders(provider, blockInfos)
  fs.writeFileSync(blocksFile, JSON.stringify(blockInfos, null, 2) + '\n')

  return { blockInfos, headers }
}
