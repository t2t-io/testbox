
BaseApp = require "./BaseApp"

class TestApp extends BaseApp
  (@opts, @helpers) ->
    super opts, helpers
    console.error "Test app"

module.exports = exports = TestApp