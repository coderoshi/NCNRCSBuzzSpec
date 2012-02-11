csv = require('csv')
redisClient = require('redis').createClient(6379)
log = console.log

processedLines = 0

trackLineCount = ->
  if ++processedLines % 1000 == 0
    log "Lines Processed: #{processedLines}"

populateRedis = ->
  file = csv().fromPath('group_membership.tsv', delimiter: '\t', quote: '')

  file.on 'data', (data, index) ->
    artist = data[2]
    band = data[3]

    return trackLineCount() if band == '' or artist == ''

    roles = data[4].split ','
    roles = [] if roles.length == 1 and roles[0] == ''

    redisClient.sadd("band:#{band}", artist)
    roles.forEach (role)->
      redisClient.sadd("artist:#{band}:#{artist}", role)

    trackLineCount()

  file.on 'end', (total_lines) ->
    log "Total Lines Processed: #{processedLines}"
    redisClient.quit()

populateRedis()
