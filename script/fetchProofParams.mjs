import util from 'util'
import fs from 'fs'
import { getProvider } from './lib/provider.mjs'
import { reverseBytesNArray } from './lib/coder.mjs'
import { getTransactionInfo, getTransactionHex, getTransactionMerkleProof, getParentsAndChildrenHashes, getProofTxnBlockHeader } from './lib/api.mjs'

  // usage: `node script/fetchProofParams.mjs <provider> <step:initialHeight> <txId>`
  // like for deposit and confirm:
  //    679162210bf2d1a467d73356e5e82a3e4106e4d24472998f6d4de7d2ed2de9ae,2bd72f7379dbd73acc06a2810eb43f9f4146acf79ac58b2366c049eac9287977
  // provider: 1 for blockstream, 2 for mutinynet
  // output:  Field                       Size        Format
  //          merkle proof count          variable    compact size
  //          merkle proof                32 bytes    natural byte order
  //          parent blockHash count      variable    compact size
  //          parent blockHash            32 bytes    natural byte order
  //          children blockHash count    variable    compact size
  //          children blockHash          32 bytes    natural byte order
  //          transaction index in block  variable    compact size
  //          raw transaction             variable    bitcoin transaction format
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
    const header = await getProofTxnBlockHeader(provider, proofInfo)
    fs.writeFileSync(file, JSON.stringify(proofInfo, null, 2) + '\n')

    // console.log(merkleProof, parents, children, proofInfo.block_index, header, rawTx)

    const blueUnderline = '\x1b[4;34m%s\x1b[0m'
    console.log('>>>>>>>>>> Reversed byte order below, as seen in exploer <<<<<<<<<<<<')
    console.log(util.format(blueUnderline, 'merkleProof'))
    console.log(merkleProof.merkle.join(''))
    console.log()
    console.log('>>>>>>>>>> Natural byte order below, use them directly for calculations <<<<<<<<<<<<')
    console.log(util.format(blueUnderline, 'merkleProof'))
    console.log(reverseBytesNArray(merkleProof.merkle.join(''), 32))
    console.log()
    console.log(util.format(blueUnderline, 'parents'))
    console.log(parents.join(''))
    console.log(util.format(blueUnderline, 'children'))
    console.log(children.join(''))
    console.log(util.format(blueUnderline, 'block_index'))
    console.log(proofInfo.block_index)
    console.log(util.format(blueUnderline, 'block_height'))
    console.log(proofInfo.self.height)
    console.log(util.format(blueUnderline, 'block header'))
    console.log(header)
    console.log(util.format(blueUnderline, 'rawTx'))
    console.log(rawTx)

    // let output = ''
    // output += toCompactSize(merkleProof.merkle.length) + merkleProof.merkle.join('')
    // output += toCompactSize(parents.length) + parents.join('')
    // output += toCompactSize(children.length) + children.join('')
    // output += toCompactSize(proofInfo.block_index)
    // output += rawTx
    // console.log(output)

    console.log('>>> DONE')
  })()
