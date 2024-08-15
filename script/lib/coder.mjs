import { Buffer } from 'buffer'

export const BLOCK_HEADER_BYTES = 80
export const EPOCH_BLOCK_COUNT = 2016

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
export const toCompactSize = (size) => {
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

export const hex2bytes = (hex) => new Uint8Array(hex.match(/.{1,2}/g).map(b => parseInt(b, 16)))
export const bytes2hex = (bytes) => bytes.reduce((str, b) => str + b.toString(16).padStart(2, '0'), '')


export const reverseBytesNArray = (hex, n) => {
  hex = hex.startsWith('0x') ? hex.substring(2) : hex
  if (hex.length % (n * 2) !== 0) {
    throw new Error(`hex length must be multiple of ${n * 2}`)
  }

  const bytes = hex2bytes(hex)
  let output = ''
  for (let i = 0; i < bytes.length; i += n) {
    const bytes32 = new Uint8Array(n)
    for (let j = 0; j < n; j++) {
      bytes32[j] = bytes[i + j]
    }
    output += bytes2hex(Array.from(bytes32).reverse())
  }
  return output
}
