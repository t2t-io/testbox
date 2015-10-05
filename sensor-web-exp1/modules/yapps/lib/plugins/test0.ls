DBGT = null

timeoutA = -> 
  DBGT "timeout"

module.exports = exports = 
  name: \test0
  attach: (opts) -> 
    module.logger = opts.helpers.logger
    DBGT := -> module.logger.debug.apply module.logger, arguments
    return

  init: (done) ->
    DBGT "yes"
    setTimeout timeoutA, 100
    return done!

