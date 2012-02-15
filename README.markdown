# NodeJS, CouchDB, Neo4j, Redis, CoffeeScript Spectacular
  
  Extracted from the book [Seven Databases in Seven Weeks](http://pragprog.com/book/rwdata/seven-databases-in-seven-weeks). You must have Redis, CouchDB, Neo4j running and NodeJS and Coffeescript installed to use this. Or you could just read it, but what fun would that be?

## Populate Redis

    coffee pre_populate.coffee

## Populate CouchDB

    coffee populate_couch.coffee

## Keep Neo4j in Sync with CouchDB

This needs to be running in the background to capture changes to CouchDB

    coffee graph_sync.coffee

## Run our Bands Website

    coffee bands.coffee
