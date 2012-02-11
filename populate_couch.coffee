couchClient = require('http').createClient(5984, 'localhost')
redisClient = require('redis').createClient(6379)
log = console.log

processedBands = 0
totalBands = null

couchKeyify = (string)->
  string.replace(/[\t \?\#\\\-\+\.\,'"()*&!\/]+/g, '_').replace(/^_+/, '')

exports.couchKeyify = couchKeyify

trackLineCount = (increment)->
  processedBands += increment
  if processedBands % 1000 == 0
    log "Bands Loaded: #{processedBands}"
  if totalBands < processedBands
    log "Total Bands Loaded: #{processedBands}"
    redisClient.quit()

batchPost = (docs)->
  docsCount = docs.length

  request = couchClient.request(
    'POST'
    '/bands/_bulk_docs'
    'Content-Type' : 'application/json'
  )

  request.on 'response', (response)->
    trackLineCount(docsCount) if response.statusCode == 201

  request.on 'error', (error)->
    log "postDoc Got error: #{error.message}"

  request.end JSON.stringify(docs : docs)

populateBands = ->
  couchClient.request('PUT', '/bands').end()

  redisClient.keys 'band:*', (error, bandKeys)->
    totalBands = bandKeys.length
    readBands = 0
    bandsBatch = []

    bandKeys.forEach (bandKey)->
      bandName = bandKey.substring('band:'.length)

      redisClient.smembers bandKey, (error, artists)->
        roleBatch = []
        artists.forEach (artistName) ->
          roleBatch.push [
            'smembers'
            "artist:#{bandName}:#{artistName}"
          ]

        redisClient.
        multi(roleBatch).
        exec (err, roles)->
          i = 0
          artistDocs = []

          artists.forEach (artistName)->
            artistDocs.push( name: artistName, role : roles[i++] )

          bandsBatch.push
            _id: couchKeyify( bandName )
            name: bandName
            artists: artistDocs

          readBands++

          if bandsBatch.length >= 50 || totalBands - readBands == 0
            batchPost bandsBatch
            bandsBatch = []

populateBands() if(!module.parent)
