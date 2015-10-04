require! <[colors fs zlib moment]>
require! io: \socket.io-client

NAME = \sensorhub-client
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments
WARN = -> module.logger.warn.apply  module.logger, arguments

parseItems = (channel, buf, DEBUG) ->
  {app, compatible} = module
  packet = null
  try
    packet := JSON.parse "#{buf}"
  catch error
    return ERR error, "failed to parse raw buffer"

  {profile, id} = packet

  # Broadcast 2 kinds of events, one is compatible with `hub-router` in order to
  # let sensor-hub's plugins to do further data processing.
  #
  app.emit "data::items::#{profile}::#{id}", profile, id, 0, packet.items if compatible
  app.emit "sensor_hub_client::items::#{profile}::#{id}", profile, id, packet.items
  DEBUG "items<#{channel}> #{profile}/#{id} => #{packet.items.length} records"


module.exports = exports =
  name: NAME
  attach: (opts) ->
    app = @
    {resource, logger} = opts.helpers
    module.opts = opts
    module.logger = logger
    module.enabled = no
    module.enabled = opts.enabled if opts.enabled?
    module.compatible = no
    module.compatible = opts.compatible if opts.compatible?
    module.app = app
    DBGT "attached"

  init: (done) ->
    if not module.enabled
      WARN "loaded but disabled"
      return done!

    app = @
    {opts} = module
    {url, channel, masks} = opts
    channel = \raw unless channel?
    masks = <[* *]> unless masks?
    masks = masks.split "," if \string == typeof masks

    ws = io url

    ws.on \disconnect, -> return WARN "disconnected"

    ws.on \connect, ->
      INFO "connected to #{url} via websocket protocol"
      req = operation: \add, channel: channel, masks: masks
      ws.emit \control, JSON.stringify req

    DEBUG = if opts.verbose? and opts.verbose then INFO else DBGT

    ws.on \gz, (buf) ->
      # Before decompress the gzipped buffer, we don't know its profile and device identity
      # so, broadcast it with `sensor_hub_client` event.
      #
      DEBUG "gz: receiving #{buf.length} bytes"
      return app.emit "sensor_hub_client::gz", buf


    ws.on \raw, (buf) ->
      # Before parsing the json buffer, we don't know its profile and device identity
      # so, broadcast it with `sensor_hub_client` event.
      #
      app.emit "sensor_hub_client::raw", buf
      return parseItems \raw, buf, DEBUG


    ws.on \items, (buf) ->
      return parseItems \items, buf, DEBUG


    ws.on \item, (buf) ->
      packet = null
      try
        packet := JSON.parse "#{buf}"
      catch error
        return ERR error, "failed to parse single item json buffer: #{buf}"

      {profile, id} = packet
      {board_type, board_id, sensor, data_type} = packet.item.desc
      {value, unit_length, updated_at} = packet.item.data
      updated_at = moment updated_at
      value = "#{value}#{unit_length}"
      DEBUG "item: #{profile.yellow}/#{id.yellow}: #{updated_at.format 'YYYY/MM/DD HH:mm:ss'} #{board_type.cyan}/#{board_id.cyan}/#{sensor.cyan}/#{data_type.cyan} => #{value.green}"

      return app.emit "data::item::#{id}::#{profile}::#{board_type}::#{board_id}::#{sensor}::#{data_type}", profile, id, packet.item

    return done!

