import assert from 'assert'
import fs from 'fs'
import { getProvider } from './lib/provider.mjs'
import { getBlockInfos, getBlockHeaders } from './lib/api.mjs'

const BLOCK_HEADER_BYTES = 80

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
