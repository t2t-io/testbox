require! <[colors handlebars byline]>
{spawn, exec} = require \child_process

NAME = \script-runner-simple
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments
WARN = -> module.logger.warn.apply  module.logger, arguments

onLineCurrying = (app, name, std, line) -->
  names = [\script-runner, name, std]
  return app.emit names, name, std, line


class Runner
  (@name, @config, @app) ->
    DBGT "#{name} launched."

  start: ->
    self = @
    {app, config, name} = self
    {command, args, cwd, env} = config
    args = [] unless args?
    cwd = process.cwd! unless cwd?
    env = [] unless env?
    ne = []
    for let k, v of process.env
      ne[k] = v
    for let k, v of env
      ne[k] = v

    opts = cwd: cwd, env: ne
    child = @child = spawn command, args, opts
    child.on \close, (code) -> INFO "#{self.name} exit (#{code})"

    stdoutCB = onLineCurrying app, name, "stdout"
    stderrCB = onLineCurrying app, name, "stderr"

    stdout_reader = byline child.stdout
    stderr_reader = byline child.stderr
    stdout_reader.on \data, stdoutCB
    stderr_reader.on \data, stderrCB
    return


module.exports = exports =
  name: NAME
  attach: (opts) ->
    {resource, logger} = opts.helpers
    module.opts = opts
    module.logger = logger
    module.resource = resource
    DBGT "attached"


  init: (done) ->
    app = @
    {opts, resource} = module
    module.runners = runners = []

    try
      config = opts.scripts
      text = JSON.stringify config, null, ' '
      template = handlebars.compile text
      context = WORKDIR: resource.getWorkDir!, APPDIR: resource.getAppDir!
      text = template context
      configs = JSON.parse text
      for let c, i in configs
        DBGT "configs[#{i}] = #{JSON.stringify c}"
        runner = new Runner c.name, c, app
        runner.start!
        runners.push runner

      return done!

    catch error
      ERR error, "failed to parse config"
      return done error
