require! <[express]>

NAME = \test-webview
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
    test.get '/render', (req, res) ->
      data = 
        id: req.id
        ip: req.ip
        original-url: req.original-url
        title: \render-test

      res.render \test, data, (err, html) ->
        DBGT err, "failed to render `test`" if err?
        return composeError req, res, \general_server_error, err if err?
        return res.send html


    web.use \test, test
    return done!

