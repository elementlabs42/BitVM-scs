import util from 'util'
import child_process from 'child_process'
import fs from 'fs'
import { Buffer } from 'buffer'

const exec = util.promisify(child_process.exec)

// https://github.com/Blockstream/esplora/blob/master/API.md
const BLOCKSTREAM_BLOCK_CHUNK_SIZE = 10
const BLOCKSTREAM_API_URL = 'https://blockstream.info/api'
const BLOCKSTREAM_API_TRANSACTION = `${BLOCKSTREAM_API_URL}/tx/%s`
const BLOCKSTREAM_API_TX_HEX = `${BLOCKSTREAM_API_URL}/tx/%s/hex`
const BLOCKSTREAM_API_TX_MERKLE_PROOF = `${BLOCKSTREAM_API_URL}/tx/%s/merkle-proof`
const BLOCKSTREAM_API_BLOCKS = `${BLOCKSTREAM_API_URL}/blocks/%s`
const BLOCKSTREAM_API_BLOCK_TXIDS = `${BLOCKSTREAM_API_URL}/blocks/%s/txids`

// https://www.mutinynet.com/docs/api/rest
const MUTINYNET_BLOCK_CHUNK_SIZE = 10
const MUTINYNET_API_URL = 'https://www.mutinynet.com/api'
const MUTINYNET_API_TRANSACTION = `${MUTINYNET_API_URL}/tx/%s`
const MUTINYNET_API_TX_HEX = `${MUTINYNET_API_URL}/tx/%s/hex`
const MUTINYNET_API_TX_MERKLE_PROOF = `${MUTINYNET_API_URL}/tx/%s/merkle-proof`
const MUTINYNET_API_BLOCKS = `${MUTINYNET_API_URL}/v1/blocks/%s`
const MUTINYNET_API_BLOCK_TXIDS = `${MUTINYNET_API_URL}/blocks/%s/txids`

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
// rawTx?
// merkle_proof?
//   block_height
//   pos
//   merkle[]
// parents?[]
//   {block info}
// children?[]
//   {block info}

const CURL_RETRY = 3

const BLOCK_HEADER_BYTES = 80

const getProvider = (providerId) => {
  switch (providerId) {
    case 1:
      return {
        baseUrl: BLOCKSTREAM_API_URL,
        blockChunkSize: BLOCKSTREAM_BLOCK_CHUNK_SIZE,
        blocks: BLOCKSTREAM_API_BLOCKS,
        tx: BLOCKSTREAM_API_TRANSACTION,
        txHex: BLOCKSTREAM_API_TX_HEX,
        txIds: BLOCKSTREAM_API_BLOCK_TXIDS,
        txMerkle: BLOCKSTREAM_API_TX_MERKLE_PROOF,
      }
    case 2:
      return {
        baseUrl: MUTINYNET_API_URL,
        blockChunkSize: MUTINYNET_BLOCK_CHUNK_SIZE,
        blocks: MUTINYNET_API_BLOCKS,
        tx: MUTINYNET_API_TRANSACTION,
        txHex: MUTINYNET_API_TX_HEX,
        txIds: MUTINYNET_API_BLOCK_TXIDS,
        txMerkle: MUTINYNET_API_TX_MERKLE_PROOF,
      }
    default:
      throw new Error(`unknown provider id ${providerId}`)
  }
}

const curl = async (url, hasError) => {
  const ret = await exec(`curl -s ${url}`)
  const err = hasError ? hasError(ret.stdout) : undefined
  if (ret.stderr || err) {
    throw new Error(`curl failed: ${ret.stderr || err}`)
  }
  return ret.stdout
}

const curlWithRetry = async (url, hasError) => {
  for (let i = 1; i <= CURL_RETRY; i++) {
    try {
      return await curl(url, hasError)
    } catch (err) {
      console.log(`retry [${i}]${url} failed: ${err.message}`)
    }
    await new Promise(resolve => setTimeout(resolve, 1500))
  }
  console.error(`curl failed with ${CURL_RETRY} retries: ${url}`)
}

const jsonVerifier = (data) => {
  try {
    JSON.parse(data)
  } catch (error) {
    return 'not json'
  }
}

const getTransactionInfo = async (provider, txId) => {
  const ret = await curlWithRetry(util.format(provider.tx, txId), jsonVerifier)
  return JSON.parse(ret)
}

const getTransactionHex = async (provider, proofInfo) => {
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
const getTransactionIndex = async (provider, proofInfo) => {
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

const getTransactionMerkleProof = async (provider, proofInfo) => {
  if (proofInfo.merkle_proof) {
    return proofInfo.merkle_proof
  }
  const ret = await curlWithRetry(util.format(provider.txMerkle, proofInfo.txid), jsonVerifier)
  const merkleProof = JSON.parse(ret)
  proofInfo.merkle_proof = merkleProof
  proofInfo.block_index = merkleProof.pos
  return merkleProof
}

const getParentsAndChildrenHashes = async (provider, proofInfo) => {
  if (!(proofInfo.parents && proofInfo.children)) {
    const step = proofInfo.step
    const initialHeight = proofInfo.initial_height
    const blockHeight = proofInfo.status.block_height
    console.log(`>>> fetching parents and children for block:${blockHeight} step:${step} initialHeight:${initialHeight}...`)
    const prevKeyBlockIndex = Math.floor((blockHeight - initialHeight) / step)
    const prevKeyBlockHeight = initialHeight + prevKeyBlockIndex * step
    const nextKeyBlockHeight = prevKeyBlockHeight + step
    console.log(`>>>  fetched parents and children for prevKeyBlockHeight:${prevKeyBlockHeight} nextKeyBlockHeight:${nextKeyBlockHeight}...`)
    const blockInfos = await getBlockInfos(provider, prevKeyBlockHeight, nextKeyBlockHeight)
    proofInfo.parents = blockInfos.filter(b => b.height < blockHeight)
    proofInfo.children = blockInfos.filter(b => b.height > blockHeight)    
  }
  return { parents: proofInfo.parents.map(b => b.id), children: proofInfo.children.map(b => b.id) }
}

const getBlockInfos = async (provider, start, end) => {
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

// Buffer in nodejs only supports up to 6 bytes
// 0xffffffffffff + 1 will start to fail
// console.log(toCompactSize(0x00), 0x00)
// console.log(toCompactSize(0x01), 0x01)
// console.log(toCompactSize(0xfc), 0xfc)
// console.log(toCompactSize(0xfd), 0xfd)
// console.log(toCompactSize(0xffff - 1), 0xffff - 1)
// console.log(toCompactSize(0xffff), 0xffff)
// console.log(toCompactSize(0xffff + 1), 0xffff + 1)
// console.log(toCompactSize(0xffffffff - 1), 0xffffffff - 1)
// console.log(toCompactSize(0xffffffff), 0xffffffff)
// console.log(toCompactSize(0xffffffff + 1), 0xffffffff + 1)
// console.log(toCompactSize(0xffffffffffff - 1), 0xffffffffffff - 1)
// console.log(toCompactSize(0xffffffffffff), 0xffffffffffff)
// // console.log(toCompactSize(0xffffffffffff + 1), 0xffffffffffff + 1)
const toCompactSize = (size) => {
  if (size <= 0xfc) {
    const buffer = Buffer.allocUnsafe(1)
    buffer.writeUIntLE(size, 0, 1)
    return buffer.toString('hex')
  } else if (size <= 0xffff) {
    const buffer = Buffer.allocUnsafe(2)
    buffer.writeUIntLE(size, 0, 2)
    return 'fd' + buffer.toString('hex')
  } else if (size <= 0xffffffff) {
    const buffer = Buffer.allocUnsafe(4)
    buffer.writeUIntLE(size, 0, 4)
    return 'fe' + buffer.toString('hex')
  } else {
    const buffer = Buffer.allocUnsafe(8)
    buffer.writeUIntLE(size, 0, 6)
    return 'ff' + buffer.toString('hex')
  }
}

  // usage: `node script/fetchProofParams.mjs <provider> <step:initialHeight> <txId>`
  // provider: 1 for blockstream, 2 for mutinynet
  // output:  Field                     Size        Format        
  //          merkle proof count        variable    compact size
  //          merkle proof              32 bytes    natural byte order
  //          parent blockHash count    variable    compact size
  //          parent blockHash          32 bytes    natural byte order
  //          children blockHash count  variable    compact size
  //          children blockHash        32 bytes    natural byte order
  //          raw transaction           variable    segwit transaction format
  ; (async () => {
    const providerId = parseInt(process.argv[2])
    const provider = getProvider(providerId)
    const [step, initialHeight] = process.argv[3].toString().split(':').map(n => parseInt(n))
    const txId = process.argv[4].toString()
    const file = `proof-${providerId}-${step}_${initialHeight}-${txId.substring(0, 6)}.json`

    let proofInfo
    if (fs.existsSync(file)) {
      console.log(`>>> reading ${file}`)
      proofInfo = JSON.parse(fs.readFileSync(file, 'utf-8'))
    } else {
      proofInfo = await getTransactionInfo(provider, txId)
      proofInfo.step = step
      proofInfo.initial_height = initialHeight
    }
    if (proofInfo.status.block_height < initialHeight) {
      throw new Error(`block height lower than initialHeight: ${proofInfo.status.block_height} < ${initialHeight}`)
    }
    const rawTx = await getTransactionHex(provider, proofInfo)
    const merkleProof = await getTransactionMerkleProof(provider, proofInfo)
    const { parents, children } = await getParentsAndChildrenHashes(provider, proofInfo)
    fs.writeFileSync(file, JSON.stringify(proofInfo, null, 2) + '\n')

    let output = ''
    output += toCompactSize(merkleProof.merkle.length) + merkleProof.merkle.join('')
    output += toCompactSize(parents.length) + parents.join('')
    output += toCompactSize(children.length) + children.join('')
    output += rawTx
    console.log(output)

    console.log('>>> DONE')
  })()
