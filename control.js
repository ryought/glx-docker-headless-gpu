const axios = require('axios')
const request = require('request')
const client = axios.create({
  baseURL: 'http://localhost:8082',
  responseType: 'json',
  withCredentials: true,
})
const username = process.env.LG_USERNAME
const password = process.env.LG_PASSWORD

function control_simulation (mode) {
  return new Promise((resolve, reject) => {
    const source = axios.CancelToken.source()
    request.post({
      uri: 'https://account.lgsvlsimulator.com/users/signin',
      headers: {'Content-Type': 'application/json'},
      json: {
        'username': username,
        'password': password,
      }
    }, (err, res, data) => {
      const token = data.token
      client.put(`/users/${encodeURIComponent(token)}`)
        .then(res => {
          const cook = res.headers['set-cookie'][0].split(';')[0]
          client.request({
            method: 'post',
            cancelToken: source.token,
            url: mode === 'stop' ? '/simulations/5/stop' : '/simulations/5/start',
            headers: {
              Cookie: cook
            },
          })
            .then(res => {
              console.log('done', res.data)
              resolve()
            })
            .catch(err => {
              console.log('error', err)
              reject(err)
            })
        })
    })
  })
}

control_simulation('start')
  .then((res) => { console.log('kicked') })

module.exports = {
  control_simulation,
}
