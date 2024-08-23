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
  depositorEvmAddress: '0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd',
  pegInValue: 131072,
  depositorPubKey: '0xedf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b',
  withdrawerEvmAddress: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
  pegOutValue: 131072,
  pegOutTimestamp: 1722328130,
  withdrawerPubKey: '0x02f80c9d1ef9ff640df2058c431c282299f48424480d34f1bade2274746fb4df8b',
  operatorPubKey: '0x58f54b8ba6af3f25b9bafaaf881060eafb761c6579c22eab31161d29e387bcc0',
  nOfNPubKey: '0xd0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4',
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
