import util from 'util'
import { curlWithRetry, jsonVerifier } from './https.mjs'

// blocksteam.info (same in mutinynet.com) block info
// type BlockInfo = {
//   id: string,
//   height: number,
//   version: number,
//   timestamp: number,
//   tx_count: number,
//   size: number,
//   weight: number,
//   merkle_root: string,
//   previousblockhash: string,
//   mediantime: number,
//   nonce: number,
//   bits: number,
//   difficulty: number,
//   header?: string
// }

// transaction info
// txid
// version
// locktime
// size
// weight
// fee
// vin[]
//   txid
//   vout
//   is_coinbase
//   scriptsig
//   scriptsig_asm
//   inner_redeemscript_asm
//   inner_witnessscript_asm
//   sequence
//   witness[]
//   prevout (previous output in the same format as in vout below)
//   (Elements only)
//   is_pegin
//   issuance (available for asset issuance transactions, null otherwise)
//     asset_id
//     is_reissuance
//     asset_id
//     asset_blinding_nonce
//     asset_entropy
//     contract_hash
//     assetamount or assetamountcommitment
//     tokenamount or tokenamountcommitment
// vout[]
//   scriptpubkey
//   scriptpubkey_asm
//   scriptpubkey_type
//   scriptpubkey_address
//   value
//   (Elements only)
//   valuecommitment
//   asset or assetcommitment
//   pegout (available for peg-out outputs, null otherwise)
//     genesis_hash
//     scriptpubkey
//     scriptpubkey_asm
//     scriptpubkey_address
// status
//   confirmed (boolean)
//   block_height (available for confirmed transactions, null otherwise)
//   block_hash (available for confirmed transactions, null otherwise)
//   block_time (available for confirmed transactions, null otherwise)
// step
// initial_height
// block_index?
// block_header?
// rawTx?
// merkle_proof?
//   block_height
//   pos
//   merkle[]
// self
//   {block info}
// parents?[]
//   {block info}
// children?[]
//   {block info}

export const getTransactionInfo = async (provider, txId) => {
  const ret = await curlWithRetry(util.format(provider.tx, txId), jsonVerifier)
  return JSON.parse(ret)
}

export const getTransactionHex = async (provider, proofInfo) => {
  if (proofInfo.rawTx) {
    return proofInfo.rawTx
  }
  console.log(`>>> fetching raw tx for block:${proofInfo.status.block_height} txId:${proofInfo.txid} ...`)
  const rawTx = await curlWithRetry(util.format(provider.txHex, proofInfo.txid))
  console.log(`>>>  fetched raw tx for block:${proofInfo.status.block_height} txId:${proofInfo.txid} ...`)
  proofInfo.rawTx = rawTx
  return rawTx
}

// merkle_proof has transaction index, this is ignored
export const getTransactionIndex = async (provider, proofInfo) => {
  if (proofInfo.block_index) {
    return proofInfo.block_index
  }
  const ret = await curlWithRetry(util.format(provider.txIds, proofInfo.status.block_hash), jsonVerifier)
  const txIds = JSON.parse(ret)
  const txIndex = txIds.indexOf(proofInfo.txid)
  if (txIndex < 0) {
    throw new Error(`txId ${proofInfo.txid} not found in block ${proofInfo.status.block_hash}`)
  }
  proofInfo.block_index = txIndex
  return txIndex
}

export const getTransactionMerkleProof = async (provider, proofInfo) => {
  if (proofInfo.merkle_proof) {
    return proofInfo.merkle_proof
  }
  const ret = await curlWithRetry(util.format(provider.txMerkle, proofInfo.txid), jsonVerifier)
  const merkleProof = JSON.parse(ret)
  proofInfo.merkle_proof = merkleProof
  proofInfo.block_index = merkleProof.pos
  return merkleProof
}

export const getParentsAndChildrenHashes = async (provider, proofInfo) => {
  if (!(proofInfo.parents && proofInfo.children && proofInfo.self)) {
    const step = proofInfo.step
    const initialHeight = proofInfo.initial_height
    const blockHeight = proofInfo.status.block_height
    console.log(`>>> fetching parents and children for block:${blockHeight} step:${step} initialHeight:${initialHeight}...`)
    const prevKeyBlockIndex = Math.floor((blockHeight - initialHeight) / step)
    const prevKeyBlockHeight = initialHeight + prevKeyBlockIndex * step
    const nextKeyBlockHeight = prevKeyBlockHeight + step
    console.log(`>>>  fetched parents and children for prevKeyBlockHeight:${prevKeyBlockHeight} nextKeyBlockHeight:${nextKeyBlockHeight}...`)
    const blockInfos = await getBlockInfos(provider, prevKeyBlockHeight, nextKeyBlockHeight)
    proofInfo.self = blockInfos.find(b => b.height === blockHeight)
    proofInfo.parents = blockInfos.filter(b => b.height < blockHeight)
    proofInfo.children = blockInfos.filter(b => b.height > blockHeight)
  }
  await getBlockHeaders(provider, proofInfo.parents)
  await getBlockHeaders(provider, proofInfo.children)
  proofInfo.self.header = (await getBlockHeaders(provider, [proofInfo.self]))[0]
  return { parents: proofInfo.parents.map(b => b.header), children: proofInfo.children.map(b => b.header) }
}

export const getBlockInfos = async (provider, start, end) => {
  const count = end - start + 1
  const chunks = Math.ceil(count / provider.blockChunkSize)
  const blockInfos = await Promise.all(Array(chunks).fill(0).map(async (_, i) => {
    const apiParam = end - i * provider.blockChunkSize
    console.log(`>>> fetching 10 blocks from ${apiParam - provider.blockChunkSize} to ${apiParam}...`)
    const ret = await curlWithRetry(util.format(provider.blocks, apiParam), jsonVerifier)
    console.log(`>>>  fetched 10 blocks from ${apiParam - provider.blockChunkSize} to ${apiParam}...`)
    return JSON.parse(ret)
  }))
  return blockInfos.flat().sort((a, b) => a.height - b.height).filter(b => b.height >= start)
}

export const getBlockInfoByHeight = async (provider, height) => {
  const ret = await curlWithRetry(util.format(provider.blocks, height), jsonVerifier)
  return JSON.parse(ret)[0]
}

export const getBlockHeaders = async (provider, blockInfos) => {
  const headers = await Promise.all(blockInfos.map(async (info, i) => {
    if (info.header) {
      return info.header
    } else {
      console.log(`>>> fetching block header for ${info.height} ...`)
      const header = await getBlockHeader(provider, info.id)
      console.log(`>>>  fetched block header for ${info.height} ${info.id}...`)
      blockInfos[i].header = header
      return header
    }
  }))
  return headers
}

const getBlockHeader = async (provider, blockHash) => {
  const header = await curlWithRetry(util.format(provider.blockHeader, blockHash), (stdout) => {
    if (stdout.length !== 160) {
      return `block header ${stdout} length ${stdout.length} != 160`
    }
  })
  return header
}

export const getProofTxnBlockHeader = async (provider, proofInfo) => {
  if (proofInfo.block_header) {
    return proofInfo.block_header
  } else {
    const header = await getBlockHeader(provider, proofInfo.status.block_hash)
    proofInfo.block_header = header
    return header
  }
}
