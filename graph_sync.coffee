events = require('events')
esc = require('querystring').escape
neo4jClient = require('./neo4j_caching_client.js').createClient( limit: 10 )
couchWatcher = require('./watch_changes_continuous.js').createWatcher( db: 'bands' )
redisClient = require('redis').createClient(6379)

feedBandToRedis = (band)->
  redisClient.set "band-name:#{band.name}", 1
  band.artists.forEach (artist)->
    redisClient.set "artist-name:#{artist.name}", 1
    artist.role.forEach (role)->
      redisClient.set "role-name:#{role}", 1

feedBandToNeo4j = (band, progress)->
  lookup = neo4jClient.lookupOrCreateNode
  relate = neo4jClient.createRelationship

  lookup 'bands', 'name', band.name, (bandNode)->
    progress.emit 'progress', 'band'
    band.artists.forEach (artist)->
      lookup 'artists', 'name', artist.name, (artistNode)->
        progress.emit 'progress', 'artist'
        relate bandNode.self, artistNode.self, 'member', ()->
          progress.emit 'progress', 'member'
        artist.role.forEach (role)->
          lookup 'roles', 'role', role, (roleNode)->
            progress.emit 'progress', 'role'
            relate artistNode.self, roleNode.self, 'plays', ()->
              progress.emit 'progress', 'plays'

processBand = (band, progress)->
  addBand = false
  band.artists.forEach (artist)->
    addBand = true if artist.role.length

  if addBand
    feedBandToRedis(band)
    feedBandToNeo4j(band, progress)

stats = { doc:0, band:0, artist:0, member:0, role:0, plays:0 }
progress = new events.EventEmitter()
timer = setInterval( ->
  console.log(stats)
, 1000)

progress.on 'progress', (type)->
  stats[type] = (stats[type] || 0) + 1

couchWatcher
.on('change', (data)->
  progress.emit 'progress', 'doc'
  processBand(data.doc, progress) if data.doc and data.doc.name
)
.start()
