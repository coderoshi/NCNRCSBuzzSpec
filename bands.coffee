bricks = require('bricks')
mustache = require('mustache')
fs = require('fs')

couchUtil = require('./populate_couch')

couchClient = require('http').createClient(5984, 'localhost')
redisClient = require('redis').createClient(6379)
gremlin = require('./neo4j_caching_client.js').createClient().runGremlin
log = console.log


writeTemplate = (response, innerHtml, values)->
  file_data = fs.readFileSync('template.html', 'utf8')
  html = file_data.replace("[[YIELD]]", innerHtml)

  response.write mustache.to_html( html, values )
  response.end()

processBuffer = (response, callback)->
  buffer = ''

  response.on 'data', (chunk)->
    buffer += chunk

  response.on 'end', ()->
    buffer = 'null' if buffer == ''
    callback JSON.parse(buffer)

getCouchDoc = (path, httpResponse, callback)->
  request = couchClient.request 'GET', path, 'Content-Type':'application/json'

  request.on 'response', (response)->
    if response.statusCode != 200
      writeTemplate httpResponse, '', message: "Value not found"
    else
      processBuffer response, (couchObj) -> callback(couchObj)

  request.on 'error', (error)->
    log "postDoc Got error: #{error.message}"

  request.end()

appServer = new bricks.appserver()

appServer.addRoute "^/", appServer.plugins.request

appServer.addRoute "^/$", (req, res)->
  writeTemplate res, '', message: "Find a band"

appServer.addRoute "^/band$", (req, res)->
  bandName = req.param('name')
  bandNodePath = '/bands/' + couchUtil.couchKeyify( bandName )
  membersQuery = "g.V[[name:\"#{bandName}\"]]"
  membersQuery += '.out("member").in("member").uniqueObject.name'

  getCouchDoc bandNodePath, res, (couchObj)->
    gremlin membersQuery, (graphData)->
      artists = couchObj and couchObj['artists']
      values = { band: bandName, artists: artists, bands: graphData }

      body = '<h2>{{band}} Band Members</h2>'
      body += '<ul>{{#artists}}'
      body += '<li><a href="/artist?name={{name}}">{{name}}</a></li>'
      body += '{{/artists}}</ul>'
      body += '<h3>You may also like</h3>'
      body += '<ul>{{#bands}}'
      body += '<li><a href="/band?name={{.}}">{{.}}</a></li>'
      body += '{{/bands}}</ul>'

      writeTemplate res, body, values

appServer.addRoute "^/artist$", (req, res)->
  artistName = req.param('name')
  rolesQuery = "g.V[[name:\"#{artistName}\"]].out('plays').role.uniqueObject"
  bandsQuery = "g.V[[name:\"#{artistName}\"]].in('member').name.uniqueObject"

  gremlin rolesQuery, (roles)->
    gremlin bandsQuery, (bands)->
      values = { artist: artistName, roles: roles, bands: bands }

      body = '<h3>{{artist}} Performs these Roles</h3>'
      body += '<ul>{{#roles}}'
      body += '<li>{{.}}</li>'
      body += '{{/roles}}</ul>'
      body += '<h3>Play in Bands</h3>'
      body += '<ul>{{#bands}}'
      body += '<li><a href="/band?name={{.}}">{{.}}</a></li>'
      body += '{{/bands}}</ul>'
      
      writeTemplate res, body, values

appServer.addRoute "^/search$", (req, res)->
  query = req.param('term')

  redisClient.keys "band-name:"+query+"*", (error, keys)->
    bands = []
    keys.forEach (key)->
      bands.push key.replace("band-name:", '')
    res.write JSON.stringify(bands)
    res.end()


appServer.addRoute ".+", appServer.plugins.fourohfour
appServer.addRoute ".+", appServer.plugins.loghandler, section: "final"

log "Starting Server on port 8080"
appServer.createServer().listen 8080
