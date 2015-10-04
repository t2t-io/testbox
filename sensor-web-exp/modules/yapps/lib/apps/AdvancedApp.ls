
BaseApp = require "./BaseApp"

class AdvancedApp extends BaseApp
  (@opts, @helpers) ->
    super opts, helpers
    console.error "Advanced app"

module.exports = exports = AdvancedApp