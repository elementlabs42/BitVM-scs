import util from 'util'
import child_process from 'child_process'

const exec = util.promisify(child_process.exec)

const CURL_RETRY = 3

const curl = async (url, hasError) => {
  const ret = await exec(`curl -s ${url}`)
  const err = hasError ? hasError(ret.stdout) : undefined
  if (ret.stderr || err) {
    throw new Error(`curl failed: ${ret.stderr || err}`)
  }
  return ret.stdout
}

export const curlWithRetry = async (url, hasError) => {
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

export const jsonVerifier = (data) => {
  try {
    JSON.parse(data)
  } catch (error) {
    return 'not json'
  }
}
