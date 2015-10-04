require! <[colors handlebars byline]>
{spawn, exec} = require \child_process

NAME = \storage-cmd
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments
WARN = -> module.logger.warn.apply  module.logger, arguments


module.exports = exports =
  name: NAME
  attach: (opts) ->
    {resource, logger} = opts.helpers
    module.opts = opts
    module.logger = logger
    module.resource = resource
    DBGT "attached"


  init: (done) ->
    app = @
    {storage} = app
    return done new Error "#{exports.name.gray} depends on plugin #{'storage'.yellow} but missing" unless storage?

    app.on 'script-runner::*::*', (name, std, line) ->
      text = "#{line}"
      DBGT "#{name}:#{std.cyan}: #{text.gray}"

      return false unless std == "stdout"
      return false unless text.startsWith "DAT: "

      try
        text = text.substring 5
        tokens = text.split '\t'
        names = tokens[0].split '/'

        unit_length = tokens[2]
        v = tokens[1]
        value = parseFloat v
        board_type = names[0]
        board_id = names[1]
        sensor = names[2]
        data_type = names[3]

        return ERR "unit_length is empty" unless unit_length?
        return ERR "value is empty" unless value?
        return ERR "board_type is empty" unless board_type?
        return ERR "board_id is empty" unless board_id?
        return ERR "sensor is empty" unless sensor?
        return ERR "data_type is empty" unless data_type?

        storage.updateData board_type, board_id, sensor, data_type, value, unit_length, -> return
        INFO "#{name}: #{tokens[0].yellow} #{v.green}#{unit_length}" if module.opts.verbose

      catch error
        ERR error, "failed to parse data line from #{name}: #{text}"

    return done!
