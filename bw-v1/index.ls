#!/usr/bin/env lsc
#
# Dependencies
#
require! <[http express colors lodash noble mkdirp async]>
sio = require \socket.io
lsm = require \livescript-middleware


# Constants
#
PORT = 3000
LIVESCRIPT_WORKDIR = "#{__dirname}/work/js"
DIRS = """
  #{LIVESCRIPT_WORKDIR}
  #{__dirname}/work/css
"""

ERR_EXIT = (code, message) ->
  console.error message
  process.exit code



# Initialization
#
dirs = DIRS.split '\n'
(err) <- async.each-series dirs, mkdirp
return ERR_EXIT 1, "unexpected error when making directories #{DIRS}, err: #{err}" if err?



# Express middleware setup
#
app = express!
app.use \/assets, express.static "#{__dirname}/assets"
app.use '/', lsm src: "#{__dirname}/assets/livescript", dest: LIVESCRIPT_WORKDIR
app.use '/', express.static LIVESCRIPT_WORKDIR
app.get '/', (req, res) -> res.redirect \/assets/index.html



# WebSocket for http://0.0.0.0:${PORT}/bw
#
server = http.Server app
io = sio server
bw = io.of \bw
bw.on \connection, (c) ->
  console.log "incoming connection"



server.listen PORT, -> console.log "listening http://127.0.0.1:3000"