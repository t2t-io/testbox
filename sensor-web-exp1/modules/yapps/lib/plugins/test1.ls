require! <[noble]>
DBGT = null


module.exports = exports = 
  name: \test1
  attach: (opts) -> 
    module.logger = opts.helpers.logger
    DBGT := -> module.logger.debug.apply module.logger, arguments
    return

  init: (done) ->
    DBGT "yes"
    return done!

