#!/usr/bin/env lsc
# require \source-map-support .install!
require! <[yapps]>

app = yapps.createApp \web, do
  plugins: []
  verbose: yes

app.init (err) ->
  console.error "exit with err: #{err}" if err?
  return process.exit 1 if err?
  INFO "App ready!!"

  # plugins: <[storage storage-logger storage-webapi storage-ws uart-board script-runner-simple storage-cmd]>
