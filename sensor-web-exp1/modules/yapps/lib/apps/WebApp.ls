
BaseApp = require "./BaseApp"

class WebApp extends BaseApp
  (@opts, @helpers) ->
    super opts, helpers
    @default_plugins = <[web std-webapi]>

  init: (done) ->
    self = @
    super (err) ->
      return done err if err?
      {web} = self.app
      return web.start done

module.exports = exports = WebApp