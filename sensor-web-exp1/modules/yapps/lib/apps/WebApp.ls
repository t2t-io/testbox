require! <[y-web y-webapi-std]>
BaseApp = require "./BaseApp"

class WebApp extends BaseApp
  (@opts, @helpers) ->
    super opts, helpers
    @.add-plugin require \y-web
    @.add-plugin require \y-webapi-std

  init: (done) ->
    self = @
    super (err) ->
      return done err if err?
      {web} = self.app
      return web.start done

module.exports = exports = WebApp
