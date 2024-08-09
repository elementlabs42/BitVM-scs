// https://github.com/Blockstream/esplora/blob/master/API.md
// GET /blocks[/:start_height]
// Returns the 10 newest blocks starting at the tip or at start_height if specified.
//
// start_height is the highest block height to return
// the result is actually counting backwards from 'start_height'
const BLOCKSTREAM_API_URL = 'https://blockstream.info/api'
const BLOCKSTREAM_BLOCK_CHUNK_SIZE = 10

// https://www.mutinynet.com/docs/api/rest
// GET /v1/blocks[/:startHeight]
const MUTINYNET_API_URL = 'https://www.mutinynet.com/api'
const MUTINYNET_BLOCK_CHUNK_SIZE = 10

const getAPIs = (baseUrl, blockChunkSize) => {
  return {
    blockChunkSize,
    blocks: `${baseUrl}/blocks/%s`,
    blockHeader: `${baseUrl}/block/%s/header`,
    txIds: `${baseUrl}/blocks/%s/txids`,
    tx: `${baseUrl}/tx/%s`,
    txHex: `${baseUrl}/tx/%s/hex`,
    txMerkle: `${baseUrl}/tx/%s/merkle-proof`,
  }
}

export const getProvider = (providerId) => {
  switch (providerId) {
    case 1:
      return getAPIs(BLOCKSTREAM_API_URL, BLOCKSTREAM_BLOCK_CHUNK_SIZE)
    case 2:
      return getAPIs(MUTINYNET_API_URL, MUTINYNET_BLOCK_CHUNK_SIZE)
    default:
      throw new Error(`unknown provider id ${providerId}`)
  }
}
