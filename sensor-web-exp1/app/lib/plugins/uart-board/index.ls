require! <[path colors url]>

NAME = \uart-board
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply module.logger, arguments
ERR = -> module.logger.error.apply module.logger, arguments


compileSpec = (spec) ->
  new_spec = []
  for let sensor, i in spec
    for let type, j in sensor.types
      s = sensor: sensor.name, type: type
      new_spec.push s
  return new_spec


dataUpdate = (board_type, board_id, sensor, data_type, value, unit_length='') ->
  p = "/#{board_type}/#{board_id}/#{sensor}/#{data_type}"
  v = "#{value}#{unit_length}"
  INFO "data #{p.cyan} (#{v.green})" if module.opts.verbose
  return module.storage.updateData board_type, board_id, sensor, data_type, value, unit_length, (err) ->
    return ERR "failed to update #{board_type}/#{board_id}/#{sensor}/#{data_type} with value #{value}" if err?


handleData = (handler, spec, line, host) ->
  c = line.charAt 0
  v = line.substring 1
  value = null
  found = no
  for let s, i in spec
    if not found
      {sensor} = s
      {prefix, range, parse, name} = s.type
      if c == prefix
        try
          value := parse v
          found := true
          if handler.preprocessData sensor, s.type, value
            if value > range.high or value < range.low
              ERR "failed to parse #{sensor}/#{name} with prefix #{prefix}, out-of-range, value = #{value} not in [#{range.low} .. #{range.high}]"
            else
              DBGT "#{sensor}/#{name}: #{value}"
              handler.processData sensor, s.type, value, dataUpdate

        catch error
          ERR "1.failed to parse #{sensor}/#{name} with prefix #{prefix} for line: #{line}, err: #{error}"
  if not found then ERR "unexpected output: #{line.red}"



module.exports = exports =
  name: NAME
  attach: (opts) ->
    module.opts = opts
    module.logger = opts.helpers.logger
    DBGT "initialized"
    return

  init: (done) ->
    app = @
    storage = module.storage = @storage
    {opts} = module
    {logger} = opts.helpers

    # dependency check at initialization time
    return done new Error "#{exports.name.gray} depends on plugin #{'storage'.yellow} but missing" unless storage?

    module.communicators = []

    for let c, i in opts.communicators
      {name, bearer, parser, config} = c
      tokens = url.parse c.url
      protocol = tokens.protocol.split ':'
      protocol = protocol[0]

      try
        handlerClass = require "./parsers/#{parser}"
        handler = new handlerClass name, bearer, config, logger
        handler.setVerbose opts.verbose
        spec = compileSpec handler.getSpec!

        communicatorClass = require "./#{protocol}"
        communicator = new communicatorClass i, name, bearer, tokens, config, logger
        communicator.setVerbose opts.verbose
        communicator.setDataListener (host, name, bearer, line) ->
          return handleData handler, spec, line, host

        communicator.start!
        module.communicators.push communicator
        INFO "successfully initiate communicators[#{i}] - #{name.green} - #{c.url.yellow}"
      catch error
        ERR "failed to load communicators[#{i}] - #{name.red} #{c.url}, err: #{error}"

    return done!

