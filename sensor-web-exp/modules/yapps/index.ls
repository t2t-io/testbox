APPS =
  base: \BaseApp
  test: \TestApp
  advanced: \AdvancedApp
  web: \WebApp

loggerCurrying = (name, level, message) --> console.error "yapps[#{name}]:#{level}: #{message}"


createApplication = (type, opts) ->
  app_type_name = \BaseApp
  for let key, value of APPS
    app_type_name := value if type == key

  if opts.verbose? and opts.verbose
    global.DBG = loggerCurrying type, \debug
  else
    global.DBG = (message) -> return

  global.INFO = loggerCurrying type, \info

  try
    helpers =
      util: require './lib/util'
      resource: require './lib/resource'
      timer: require './lib/timer'
      async-executor: require './lib/async-executor'

    app_class = require "./lib/apps/#{app_type_name}"
    app = new app_class opts, helpers
    return app
  catch error
    INFO "failed to createApplication '#{app_type_name}', err: #{error}"
    return process.exit 1



findName = ->
  # Retrieve `(/workspaces/esys_modules/yapps/test/testapp0/app.ls:3:13)`
  # from the function-call stack.
  #
  ex = new Error!
  regexp = /\(.*\/app.(j|l)s:.*\)/
  matches = regexp.exec ex.stack
  return \unknown unless matches?

  # Parse `(/workspaces/esys_modules/yapps/test/testapp0/app.ls:3:13)`
  # in order to get `testapp0` as return value.
  #
  line = matches[0]
  line = line.substring 1, line.length - 2
  line.replace /:.*/ , ""
  tokens = line.split '/'
  return \unknown unless tokens.length >= 2
  return tokens[tokens.length - 2]




module.exports = exports =
  createApp: (type, opts) ->
    app_type = null
    app_opts = null
    if type?
      if \string == typeof type
        app_type = type
        app_opts = opts
      else if \object == typeof type
        app_type = \base
        app_opts = type
    else
      app_type = \base
      app_opts = {}

    app_opts.name = findName! unless app_opts.name?
    return createApplication app_type, app_opts
