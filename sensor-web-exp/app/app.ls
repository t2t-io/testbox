#!/usr/bin/env lsc
require! <[yapps]>

app = yapps.createApp \web, do
  plugins: <[storage storage-logger storage-webapi storage-ws uart-board script-runner-simple storage-cmd]>
  verbose: yes

app.init (err) ->
  console.error "exit with err: #{err}" if err?
  return process.exit 1 if err?
  INFO "App ready!!"
