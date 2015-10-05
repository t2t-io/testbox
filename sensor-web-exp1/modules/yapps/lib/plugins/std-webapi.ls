require! <[express]>
{keys} = require 'prelude-ls'

NAME = \std-webapi
DBGT = null

module.exports = exports = 
  name: NAME
  attach: (opts) -> 
    module.logger = opts.helpers.logger
    DBGT := -> module.logger.debug.apply module.logger, arguments
    return


  init: (done) -> 
    app = @
    {web, parent} = app
    {composeError, composeData} = web.helpers

    std = express!

    # Get the configuration of entire app, including
    #   - name
    #   - type (app-type class, e.g. BaseApp, WebApp)
    #   - plugins
    #   - api end-points
    #   - websocket name-spaces
    #   - opts (e.g. host, port, upload_path, ...)
    #
    std.get '/config', (req, res) ->
      {api_routes, wss} = web
      plugins = parent.plugin_instances
      plugin_names = []
      for let p, i in plugins
        plugin_names.push p.name

      config = 
        name: parent.name
        type: parent.type
        plugins: plugin_names
        api_endpoints: keys api_routes
        websocket_namespaces: keys wss
        opts: web._opts

      return composeData req, res, config, 200


    # Always response `world` as regular check.
    #
    std.get '/hello', (req, res) -> res.send "world"


    # Always response current date-time on the server.
    #
    std.get '/time', (req, res) -> res.send "#{JSON.stringify new Date!}"

    # Exit gracefully, 1 second later.
    #
    std.get '/exit', (req, res) ->
      res.send "will shutdown gracefully ...\n"
      exit = -> process.exit 0
      setTimeout exit, 1000ms


    # Restart the app with exit code `230`.
    #
    std.get '/restart', (req, res) ->
      res.send "will restart immediately ...\n"
      exit = -> process.exit 230
      setTimeout exit, 1000ms


    web.useApi \std, std
    return done!
