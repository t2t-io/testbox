require 'time-require' if process.env[\TIME_REQUIRE] == "true"
require! <[broadway optimist extendify bunyan bunyan-debug-stream bunyan-rotating-file path colors]>

#
# Apply command-line settings on the global configuration.
#
# E.g. "-i influxdb.server.port=13" will be applied to set
#      global.config["influxdb"]["server"]["port"] = 13
#
applyCmdConfigs = (settings, type) ->
  if !settings then return
  settings = if settings instanceof Array then settings else [settings]
  for s in settings
    tokens = s.split "="
    prop = tokens[0]
    value = tokens[1]
    if '"' == value.charAt(0) and '"' == value.charAt(value.length - 1)
      value = value.substr 1, value.length - 2
    else
      if "'" == value.charAt(0) and "'" == value.charAt(value.length - 1) then value = value.substr 1, value.length - 2
    names = prop.split "."
    lastName = names.pop!
    config = global.config
    for n in names
      config = config[n]
    switch type
      | "string"    => config[lastName] = value
      | "integer"   => config[lastName] = parseInt value
      | "boolean"   => config[lastName] = "true" == value.toLowerCase!
      | "str_array" => config[lastName] = value.split ','
      | otherwise   => config[lastName] = value
    INFO "applying #{prop} = #{config[lastName]}"



InitFunctions =
  * name: \string-helpers
    func: ->
      if typeof String.prototype.startsWith != 'function'
        String.prototype.startsWith = (str) -> return str == this.substring 0, str.length

      if typeof String.prototype.endsWith != 'function'
        String.prototype.endsWith = (str) -> return str == this.substring this.length - str.length, this.length


  * name: \load-config
    func: ->
      {resource} = module
      opt = optimist.usage 'Usage: $0'
        .alias 'c', 'config'
        .describe 'c', 'the configuration set, might be default, bbb0, ...'
        .default 'c', 'default'
        .alias 'b', 'config_bool'
        .describe 'b', 'overwrite a configuration with boolean value, e.g. -b "system.influxServer.secure=false"'
        .alias 's', 'config_string'
        .describe 's', 'overwrite a configuration with boolean value, e.g. -b "system.influxServer.user=smith"'
        .alias 'i', 'config_int'
        .describe 'i', 'overwrite a configuration with int value, e.g. -b "behavior.notify.influxPeriod=smith"'
        .alias 'a', 'config_str_array'
        .describe 'a', 'overwrite a configuration with array of strings with delimiter character `COMMA`, e.g. -b "system.influxServer.clusters=aa.test.net,bb.test.net,cc.test.net"'
        .alias 'v', 'verbose'
        .describe 'v', 'verbose message output (level is changed to `debug`)'
        .default 'v', false
        .alias 'q', 'quiet'
        .describe 'q', 'disable logging outputs to local file, but still outputs to stderr'
        .default 'q', false
        .boolean <[h v]>
      global.argv = opt.argv

      if global.argv.h
        opt.showHelp!
        process.exit 0

      # Load configuration from $WORK_DIR/config/xxx.json, or .js
      try
        configFile = resource.resolveWorkPath 'config', "#{global.argv.config}.json"
        DBG "loading #{configFile}"
        global.config = require configFile
      catch error
        INFO "failed to load config: #{error}"

      try
        if not global.config?
          configFile = resource.resolveWorkPath 'config', "#{global.argv.config}"
          DBG "loading #{configFile}"
          global.config = require configFile
      catch error
        INFO "failed to load config: #{error}"

      return process.exit 1 unless global.config?

      applyCmdConfigs global.argv.s, "string"
      applyCmdConfigs global.argv.i, "integer"
      applyCmdConfigs global.argv.b, "boolean"
      applyCmdConfigs global.argv.a, "str_array"



class BaseApp
  (@opts, @helpers) ->
    DBG "BaseApp constructor"
    @type = \base
    @name = @opts.name
    @resource = module.resource = helpers.resource
    @async-executor = helpers.async-executor
    @default_plugins = []
    @plugin_instances = []


  initLogger: ->
    {plugins} = @opts
    {resource} = @
    app_name = @name
    prefixers =
      module: (m) ->
        return "plugin::#{m.name}" if m.plugin? and m.plugin
        return "debug::#{m.name}" if m.debug? and m.debug
        return m.name

    stringifiers = config: (c) -> return JSON.stringify c, null, 4

    for let p, i in plugins
      config = global.config[p]
      if config? and config[\logger]?
        log_config = config.logger
        if log_config[\prefixers]?
          for let name, func of log_config.prefixers
            if prefixers[name]?
              INFO "plugin[#{p}] loads a duplicate logging prefixer <#{name}>"
            else
              prefixers[name] = func

        if log_config[\stringifiers]?
          for let name, func of log_config.stringifiers
            if stringifiers[name]?
              INFO "plugin[#{p}] loads a duplicate logging prefixer <#{name}>"
            else
              stringifiers[name] = func

    DBG "verbose (-v) is enabled" if global.argv.v? and global.argv.v
    level = if global.argv.v then \debug else \info
    logging_dir = resource.resolveWorkPath \logs, ''
    logging_opts =
      name: app_name
      serializers: bunyan-debug-stream.serializers
      streams: [
        * level: level
          type: \raw
          stream: bunyan-debug-stream do
            out: process.stderr
            showProcess: no
            colors:
              debug: \gray
              info: \white
            prefixers: prefixers
            stringifiers: stringifiers

        * level: \debug
          type: \rotating-file
          path: "#{logging_dir}#{path.sep}/app.log"
          period: \1d
          count: 7
      ]

    # Remove rotating logging files
    if global.argv.q
      logging_opts.streams.pop!

    @extendify = extendify!
    logging_opts = @extendify logging_opts, global.config.logger if global.config.logger?

    global.yapp_logger = logger = bunyan.createLogger logging_opts
    app_logger = @logger = logger.child module: name: \BaseApp
    app_logger.debug "logger initiated"
    global_logger = logger.child module: name: \GLOBAL

    global.DBG = -> global_logger.debug.apply global_logger, arguments
    global.INFO = -> global_logger.info.apply global_logger, arguments
    global.WARN = -> global_logger.warn.apply global_logger, arguments
    global.ERR = -> global_logger.error.apply global_logger, arguments
    global.FATAL = -> global_logger.fatal.apply global_logger, arguments
    module.DBGT = -> app_logger.debug.apply app_logger, arguments


  init: (done) ->
    self = @
    {async-executor, resource, opts} = self
    {plugins} = opts
    if @default_plugins?
      plugins = @default_plugins ++ plugins

    for let init_func, i in InitFunctions
      DBG "booting: #{init_func.name} ..."
      init_func.func!

    @.initLogger!
    app = @app = new broadway.App
    app.parent = self

    tasks =
      * name: \dummy
        func: (ae, ctx, dbg, done) -> return done!

      * name: \load-plugins
        func: (ae, ctx, dbg, done) ->
          {config, app, plugins, self} = ctx
          for let p, i in plugins
            try
              plugin = resource.loadPlugin p
              logger = self.logger.child module: plugin: yes, name: p
              helpers = logger: logger
              helpers = self.extendify helpers, self.helpers

              c = {}
              c = self.extendify c, config[p] if config[p]?
              c = self.extendify c, helpers: helpers
              app.use plugin, c
              self.plugin_instances.push plugin
            catch error
              return done error
          return done!

      * name: \init-plugins
        func: (ae, ctx, dbg, done) ->
          {app} = ctx
          return app.init (err) -> return done err

      * name: \startup-plugins
        func: (ae, ctx, dbg, done) ->
          dbg "enter"
          return done!


    {logger} = self
    {config} = global
    context = config: config, resource: resource, app: app, plugins: plugins, self: self
    ae = new async-executor do
      type: \app
      logger: module.DBGT
      context: context

    ae.series tasks, (executor, ctx, err, results) ->
      return process.exit 0 if process.env[\TIME_REQUIRE] == "true"
      return done! unless err?
      self.logger.error err, "initialization failure"
      return done err


  get: (name) ->
    return @app[name]

  on: ->
    onFunc = @app.on
    return onFunc.apply @app, arguments


module.exports = exports = BaseApp

