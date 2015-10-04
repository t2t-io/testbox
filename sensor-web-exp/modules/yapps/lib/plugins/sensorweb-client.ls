require! <[path colors moment]>
require! io: \socket.io-client

NAME = \sensorweb-client
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments


module.exports = exports =
  name: NAME
  attach: (opts) ->
    module.opts = opts
    module.logger = opts.helpers.logger
    DBGT "attached"

  init: (done) ->
    {opts} = module
    self = @
    s = module.socket = io "#{opts.url}/#{opts.namespace}"

    s.on \disconnect, -> INFO "disconnected"

    s.on \data, (text) ->
      try
        evt = JSON.parse text
        now = moment!
        broadcast = yes
        # broadcast = no if evt.data.value == evt.data.last_value

        if broadcast
          value = "#{evt.data.value}#{evt.data.unit_length}"
          last_value = "#{evt.data.last_value}#{evt.data.unit_length}"
          update = "#{evt.data.updated_at}"
          DBGT "#{evt.desc.path.yellow} (mask: #{evt.evt.gray}): #{last_value.green} -> #{value.green}"

          {board_type, board_id, sensor, data_type} = evt.desc
          names = "ssc::#{board_type}::#{board_id}::#{sensor}::#{data_type}"
          self.emit names, evt

      catch error
        ERR error, "failed to process the text, text: #{text}"


    s.on \connect, ->
      INFO "connected to #{opts.url.cyan} (namespace: #{opts.namespace.yellow}) via websocket protocol"
      reg = command: \register, evt: "*::*::*::*"
      s.emit \config, JSON.stringify reg
      DBGT "register #{reg.evt.yellow}"
      s.emit \action, \start

    DBGT "initialized"
    done!

