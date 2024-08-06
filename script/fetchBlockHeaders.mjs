import util from 'util'
import child_process from 'child_process'
import assert from 'assert'
import fs from 'fs'

const exec = util.promisify(child_process.exec)

// https://github.com/Blockstream/esplora/blob/master/API.md
// GET /blocks[/:start_height]
// Returns the 10 newest blocks starting at the tip or at start_height if specified.
//
// start_height is the highest block height to return
// the result is actually counting backwards from 'start_height'
const BLOCKSTREAM_BLOCK_CHUNK_SIZE = 10
const BLOCKSTREAM_API_URL = 'https://blockstream.info/api'
const BLOCKSTREAM_API_BLOCKS = `${BLOCKSTREAM_API_URL}/blocks/`
const BLOCKSTREAM_API_BLOCK_HEADER = `${BLOCKSTREAM_API_URL}/block/%s/header`

// https://www.mutinynet.com/docs/api/rest
// GET /v1/blocks[/:startHeight]
const MUTINYNET_BLOCK_CHUNK_SIZE = 10
const MUTINYNET_API_URL = 'https://www.mutinynet.com/api'
const MUTINYNET_API_BLOCKS = `${MUTINYNET_API_URL}/blocks/`
const MUTINYNET_API_BLOCK_HEADER = `${MUTINYNET_API_URL}/block/%s/header`

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

const CURL_RETRY = 3

const BLOCK_HEADER_BYTES = 80

const getProvider = (providerId) => {
  switch (providerId) {
    case 1:
      return {
        baseUrl: BLOCKSTREAM_API_URL,
        blocks: BLOCKSTREAM_API_BLOCKS,
        blockHeader: BLOCKSTREAM_API_BLOCK_HEADER,
        blockChunkSize: BLOCKSTREAM_BLOCK_CHUNK_SIZE
       }
    case 2:
      return {
        baseUrl: MUTINYNET_API_URL,
        blocks: MUTINYNET_API_BLOCKS,
        blockHeader: MUTINYNET_API_BLOCK_HEADER,
        blockChunkSize: MUTINYNET_BLOCK_CHUNK_SIZE
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

const getBlockInfos = async (provider, start, end) => {
  const count = end - start + 1
  const chunks = Math.ceil(count / provider.blockChunkSize)
  const blockInfos = await Promise.all(Array(chunks).fill(0).map(async (_, i) => {
    const apiParam = end - i * provider.blockChunkSize
    console.log(`>>> fetching 10 blocks from ${apiParam - provider.blockChunkSize} to ${apiParam}...`)
    const ret = await curlWithRetry(`${provider.blocks}${apiParam}`, (stdout) => {
      try {
        JSON.parse(stdout)
      } catch (error) {
        return 'not json'
      }
    })
    console.log(`>>>  fetched 10 blocks from ${apiParam - provider.blockChunkSize} to ${apiParam}...`)
    return JSON.parse(ret)
  }))
  return blockInfos.flat().sort((a, b) => a.height - b.height).filter(b => b.height >= start)
}

const getBlockHeaders = async (provider, blockInfos) => {
  const headers = await Promise.all(blockInfos.map(async (info, i) => {
    if (info.header) {
      return info.header
    } else {
      console.log(`>>> fetching block header for ${info.height} ...`)
      const header = await curlWithRetry(util.format(provider.blockHeader, info.id), (stdout) => {
        if (stdout.length !== 160) {
          return `block header ${stdout} length ${stdout.length} != 160`
        }
      })
      console.log(`>>>  fetched block header for ${info.height} ${info.id}...`)
      blockInfos[i].header = header
      return header
    }
  }))
  return headers
}

  // usage: `node script/fetchBlockHeaders.mjs <provider> <startHeight> <count>`
  // provider: 1 for blockstream, 2 for mutinynet
  ; (async () => {
    const providerId = parseInt(process.argv[2])
    const provider = getProvider(providerId)
    const start = parseInt(process.argv[3])
    const count = parseInt(process.argv[4])
    const end = start + count - 1
    const file = `blocks-${providerId}-${start}-${end}.json`
    let blockInfos
    if (fs.existsSync(file)) {
      console.log(`>>> reading ${file}`)
      blockInfos = JSON.parse(fs.readFileSync(file, 'utf-8'))
    } else {
      blockInfos = await getBlockInfos(provider, start, end)
      // const simpleBlockInfos = blockInfos.map(b => ({ id: b.id, height: b.height, header: b.header }))
    }
    const headers = await getBlockHeaders(provider, blockInfos)
    fs.writeFileSync(file, JSON.stringify(blockInfos, null, 2) + '\n')      

    const headersString = headers.join('')
    assert(headersString.length === BLOCK_HEADER_BYTES * 2 * (end - start + 1))
    console.log(headersString)

    console.log('>>> DONE')
  })()
