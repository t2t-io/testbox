require! <[path colors moment request fs]>
require! io: \socket.io-client
require! pty: \pty.js

NAME = \matrix-client-tty
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments
WARN = -> module.logger.warn.apply  module.logger, arguments

regularCheck = -> return module.tty.onCheck!


class TTYSocket
  (@opts) ->
    @paired = no
    @connected = no
    @counter = 0

  init: (@ttt_info, done) ->
    done!
    self = @
    self.id = ttt_info.id
    s = self.socket = io "#{@opts.url}/#{@opts.namespace}"
    s.on \disconnect, -> return self.onDisconnect!
    s.on \err, (buf) -> return self.onErr buf
    s.on \connect, -> return self.onConnect!
    s.on \reconnect, (num) -> return INFO "tty[#{self.id.yellow}] on reconnect (num: #{num})"
    s.on \command, (buf) -> return self.onCommand buf
    s.on \tty, (chunk) -> return self.onWsData chunk

    s.on \connect_error, (err) -> return ERR err, "tty[#{self.id.yellow}] on connect_error"
    s.on \connect_timeout, -> return DBGT "tty[#{self.id.yellow}] on connect_timeout"
    s.on \reconnect_attempt, -> return DBGT "tty[#{self.id.yellow}] on reconnect_attempt"
    s.on \reconnecting, -> return DBGT "tty[#{self.id.yellow}] on reconnecting"
    s.on \reconnect_error, (err) -> return ERR err, "tty[#{self.id.yellow}] on reconnect_error"
    s.on \reconnect_failed, -> DBGT "tty[#{self.id.yellow}] on reconnect_failed"


  onDisconnect: ->
    @connected = no
    INFO "tty[#{@id.yellow}] onDisconnect"


  onErr: (buf) ->
    @paired = no
    INFO "tty[#{@id.yellow}] onErr: #{buf}"


  onConnect: ->
    INFO "tty[#{@id.yellow}] onConnect"
    reg = node: @id
    @socket.emit \register, JSON.stringify reg
    @connected = yes
    INFO "tty[#{@id.yellow}] registered"


  onCommand: (buf) ->
    text = "#{buf}"
    INFO "tty[#{@id.yellow}] onCommand, text = #{text}"
    try
      cmd = JSON.parse text
      return @.requestTTY cmd if cmd.type == "req-tty"
      return @.destroyTTY cmd if cmd.type == "destroy-tty"
    catch error
      ERR error, "tty[#{@id.yellow}] onCommand"
      throw error


  onWsData: (chunk) ->
    return WARN "tty[#{@id.yellow}] ws data but it's not paired!!" unless @paired
    bytes = "#{chunk.length}"
    DBGT "ws -> pty: #{bytes.green} bytes"
    @term.write chunk
    @counter = 0


  onPtyData: (chunk) ->
    return WARN "tty[#{@id.yellow}] pty data but it's not paired!!" unless @paired
    bytes = "#{chunk.length}"
    DBGT "pty -> ws: #{bytes.green} bytes"
    @socket.emit \tty, chunk
    @counter = 0


  onPtyExit: (code, signal) ->
    INFO "tty[#{@id.yellow}] pty exit: #{code}, signal: #{signal}"
    @socket.emit \depair, ""
    @paired = no
    @term.removeAllListeners \exit
    @term.removeAllListeners \data
    @term = {}


  requestTTY: (cmd) ->
    return @socket.emit \err, "already paired with other web-socket" if @paired
    INFO "tty[#{@id.yellow}] inform matrix server that PTY is ready"
    self = @
    self.socket.emit \pair, ""

    t = self.term = pty.spawn '/bin/bash', [], do
      name: \xterm-color
      cols: cmd.tty.cols
      rows: cmd.tty.rows
      cwd: process.env.HOME
      env: process.env

    self.paired = yes
    t.on \exit, (code, signal) -> return self.onPtyExit code, signal
    t.on \data, (data) -> return self.onPtyData data


  destroyTTY: (cmd) ->
    return WARN "tty[#{@id.yellow}] request to destroy but no paired TTY" unless @paired
    INFO "tty[#{@id.yellow}] destroyTTY"
    @term.destroy!


  onCheck: ->
    return true unless @paired
    @counter = @counter + 1
    return true unless @counter > 60
    WARN "tty[#{@id.yellow}] timeout, destroy TTY"
    @term.destroy!
    @counter = 0


module.exports = exports =
  name: NAME
  attach: (opts) ->
    module.logger = opts.helpers.logger
    module.tty = @tty = new TTYSocket opts
    DBGT "attached"


  init: (done) ->
    app = @
    {ttt_info, tty} = app
    return done new Error "#{exports.name.gray} depends on plugin #{'ttt_info'.yellow} but missing" unless ttt_info?

    setInterval regularCheck, 1000
    return tty.init ttt_info, (err) ->
      ERR err "initialization failure" if err?
      return done err
