require! <[path colors fs]>

NAME = \ttt-info
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments

FILE = "/tmp/ttt_system"


module.exports = exports =
  name: NAME
  attach: (opts) ->
    module.opts = opts
    module.logger = opts.helpers.logger
    DBGT "attached"


  init: (done) ->
    app = @
    settings = module.settings = app.ttt_info = {}

    data = fs.readFileSync FILE
    return done "failed to read #{FILE}" unless data?

    text = "#{data}"
    texts = text.split '\n'
    for let line, i in texts
      tokens = line.split '\t'
      settings[tokens[0].trim!] := tokens[1].trim! if tokens.length >= 2

    DBGT "initialized"
    INFO settings, "#{FILE} settings"
    return done!

