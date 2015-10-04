require! <[path colors moment]>
require! io: \socket.io-client

NAME = \serialhub-client
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments
WARN = -> module.logger.warn.apply  module.logger, arguments

regularCheck = ->
  {serialhub} = module
  now = moment!
  now.add -10s, \seconds
  new_monitors = []
  for let m, i in serialhub.monitors
    if now > m.time
      m.done "timeout to receive #{m.cmd.red} echo"
    else
      new_monitors.push m
  serialhub.monitors = new_monitors

setInterval regularCheck, 2000ms

class Client
  (@opts, @app) ->
    @monitors = []

  init: (done) ->
    {url, namespace} = @opts
    {app, monitors} = @
    INFO "connecting #{url.cyan} (namespace: #{namespace.yellow}) ..."
    u = if namespace == "" then "#{url}" else "#{url}/#{namespace}"
    s = @socket = io u

    s.on \disconnect, -> INFO "disconnected"

    s.on \data, (data) ->
      text = "#{data}"
      app.emit 'shc::data', data
      DBGT "text = #{text}"
      found = no
      for let m, i in monitors
        if not found
          if text.endsWith m.cmd
            found := yes
            if m.done? then m.done!
            monitors.splice i, 1

    s.on \connect, ->
      INFO "connected to #{url.cyan} (namespace: #{namespace.yellow}) via websocket protocol"
      c = cmd: \config, params: {name: \data, value: yes}
      s.emit \control, JSON.stringify c
      done!

  send: (text, done) ->
    DBGT "sending <#{text.cyan}> to serialhub"
    cmd = text.substring 1
    m = cmd: cmd, time: moment!, done: done
    @monitors.push m
    @socket.emit \data, text

  sendWithoutCNF: (text) ->
    DBGT "sending <#{text.cyan}> to serialhub"
    @socket.emit \data, text


module.exports = exports =
  name: NAME
  attach: (opts) ->
    module.logger = opts.helpers.logger
    module.serialhub = @serialhub = new Client opts, @
    INFO "attached"


  init: (done) ->
    serialhub = @serialhub

    @.on 'mc::cmd::invoke', (cmd) ->
      return false unless cmd.obj == "serialhub"
      obj = serialhub
      func = obj[cmd.func]
      return WARN "invoke: no such func `#{cmd.func}` in #{cmd.obj}" unless func?
      args = cmd.args
      if args?
        if Array.isArray args
          text = JSON.stringify args
          INFO "#{'matrix'.gray} request to exec #{cmd.obj.yellow}.#{cmd.func} (#{text.green})"
          func.apply obj, args
        else
          text = "#{args}"
          INFO "#{'matrix'.gray} request to exec #{cmd.obj.yellow}.#{cmd.func} (#{text.green})"
          func.apply obj, [args]
      else
        INFO "#{'matrix'.gray} request to exec #{cmd.obj.yellow}.#{cmd.func}()"
        func.apply obj, []

    return serialhub.init (err) ->
      if err?
        ERR err, "failed to initialize"
        return done err
      else
        INFO "initialized"
        return done!

