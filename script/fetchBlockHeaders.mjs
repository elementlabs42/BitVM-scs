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

// blocksteam.info block info
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

const getBlockInfos = async (start, end) => {
  const count = end - start + 1
  const chunks = Math.ceil(count / BLOCKSTREAM_BLOCK_CHUNK_SIZE)
  const blockInfos = await Promise.all(Array(chunks).fill(0).map(async (_, i) => {
    const apiParam = end - i * BLOCKSTREAM_BLOCK_CHUNK_SIZE
    console.log(`>>> fetching 10 blocks from ${apiParam - BLOCKSTREAM_BLOCK_CHUNK_SIZE} to ${apiParam}...`)
    const ret = await curlWithRetry(`${BLOCKSTREAM_API_BLOCKS}${apiParam}`, (stdout) => {
      try {
        JSON.parse(stdout)
      } catch (error) {
        return 'not json'
      }
    })
    console.log(`>>>  fetched 10 blocks from ${apiParam - BLOCKSTREAM_BLOCK_CHUNK_SIZE} to ${apiParam}...`)
    return JSON.parse(ret)
  }))
  return blockInfos.flat().sort((a, b) => a.height - b.height).filter(b => b.height >= start)
}

const getBlockHeaders = async (blockInfos) => {
  const headers = await Promise.all(blockInfos.map(async (info, i) => {
    if (info.header) {
      return info.header
    } else {
      console.log(`>>> fetching block header for ${info.height} ...`)
      const header = await curlWithRetry(util.format(BLOCKSTREAM_API_BLOCK_HEADER, info.id), (stdout) => {
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

  // usage: `node script/fetchBlockHeaders.mjs <startHeight> <count>`
  ; (async () => {
    const start = parseInt(process.argv[2])
    const count = parseInt(process.argv[3])
    const end = start + count - 1
    const file = `blocks-${start}-${end}.json`
    let blockInfos
    if (fs.existsSync(file)) {
      console.log(`>>> reading ${file}`)
      blockInfos = JSON.parse(fs.readFileSync(file, 'utf-8'))
    } else {
      blockInfos = await getBlockInfos(start, end)
      // const simpleBlockInfos = blockInfos.map(b => ({ id: b.id, height: b.height, header: b.header }))
    }
    const headers = await getBlockHeaders(blockInfos)
    fs.writeFileSync(file, JSON.stringify(blockInfos, null, 2) + '\n')      

    const headersString = headers.join('')
    assert(headersString.length === BLOCK_HEADER_BYTES * 2 * (end - start + 1))
    console.log(headersString)

    console.log('>>> DONE')
  })()
