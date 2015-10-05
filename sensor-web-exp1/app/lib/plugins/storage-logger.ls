require! <[path colors async]>

NAME = \storage-logger
DBGT = -> module.logger.debug.apply module.logger, arguments


class Logger
  (@opts) ->
    DBGT "initialized"

  onData: (desc, data) ->
    return false unless @opts.enabled? and @opts.enabled
    {value, unit_length, updated_at} = data
    value = "#{value}#{unit_length}"
    updated = "#{updated_at}"
    DBGT "#{updated} #{desc.path.yellow} #{value.green}"

  enable: (enabled) ->
    DBGT "enabled = #{enabled}, typeof `enabled` => #{typeof enabled}"
    @opts.enabled = enabled


module.exports = exports =
  name: NAME
  attach: (opts) ->
    {helpers} = opts
    module.logger = helpers.logger
    @logger = new Logger opts
    return

  init: (done) ->
    {opts} = module
    {storage, logger} = @

    # dependency check at initialization time
    return done new Error "#{exports.name.gray} depends on plugin #{'storage'.yellow} but missing" unless storage?

    storage.on '*::*::*::*', (desc, data) -> return logger.onData desc, data
    return done!
