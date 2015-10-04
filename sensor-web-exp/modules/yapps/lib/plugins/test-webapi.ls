require! <[express]>

NAME = \test-webapi
DBGT = null

module.exports = exports = 
  name: NAME
  attach: (opts) -> 
    module.logger = opts.helpers.logger
    DBGT := -> module.logger.debug.apply module.logger, arguments
    return


  init: (done) -> 
    {web} = @
    {helpers} = web
    {composeError, composeData} = helpers

    test = express!
    test.get '/echo', (req, res) ->
      req.log.debug "/echo: req_id = #{req.id}"
      data = 
        ip: req.ip
        query: req.query
        params: req.params
        original-url: req.original-url
      return composeData req, res, data


    web.useApi \test, test
    return done!
