# Populate Redis

    coffee pre_populate.coffee

# Populate CouchDB

    coffee populate_couch.coffee

# Keep Neo4j in Sync with CouchDB

This needs to be running in the background to capture changes to CouchDB

    coffee graph_sync.coffee

# Run our Bands Website

    coffee bands.coffee
