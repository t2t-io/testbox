require! <[path colors async]>

NAME = \storage-ws
DBGT = null
INFO = null
WARN = null
ERR = null


onDataCurrying = (wss, evt, event_desc, data) -->
  return wss.dataUpdate evt, event_desc, data


class WsSocket
  (@socket, @manager, @storage) ->
    self = @
    id = @id = @socket.id
    running = no
    hooks = @hooks = {}
    storage = module.storage
    INFO "ws[#{socket.id}] connected."
    socket.on 'disconnect', ->
      for let id, hook of hooks
        storage.removeListener hook.evt, hook.listener
      manager.remove id

    socket.on 'config', (text) ->
      data = {}
      try
        data := JSON.parse text
      catch error
        ERR "failed to parse text: #{text}, error: #{error}"
        return

      if data.command = "register"
        storage = module.storage
        evt = data.evt
        INFO "ws[#{socket.id}] register listener #{evt.yellow}"
        names = evt.split "::"
        listener =  onDataCurrying self, evt
        hook = listener: listener, names: names, evt: evt, id: names.join "_"
        storage.on "storage::#{hook.evt}", hook.listener
        self.hooks[hook.id] = hook
      else
        WARN "ws[#{socket.id}] unknown config command = #{config.command}"

    socket.on 'set', (buf) ->
      text = "#{buf}"
      d = null
      try
        d = JSON.parse text
      catch error
        ERR error, "ws[#{socket.id}] failed to parse json data"

      tokens = d.path.split "/"
      board_type = tokens[0]
      board_id = tokens[1]
      sensor = tokens[2]
      data_type = tokens[3]
      value = d.data.value
      unit_length = d.data.unit_length
      unit_length = '' unless unit_length?

      storage.updateData board_type, board_id, sensor, data_type, value, unit_length, (err) ->
        return ERR err, "failed to update #{d.path}" if err?
        return DBGT "ws[#{socket.id}] successful to update #{d.path} with #{value}#{unit_length}"


    socket.on 'action', (data) ->
      return self.running = yes if data == "start"
      return self.running = no if data == "stop"


  dataUpdate: (evt, event_desc, data) ->
    d =
      evt: evt
      desc: event_desc
      data: data
    text = JSON.stringify d
    @.socket.emit \data, text if @.running

    value = "#{d.data.value}#{d.data.unit_length}"
    last_value = "#{d.data.last_value}#{d.data.unit_length}"
    DBGT "ws[#{@socket.id}] send event #{evt.yellow} with data #{d.desc.path.cyan} (#{last_value.green} -> #{value.green})"


class WsManager
  (@opts) ->
    @sockets = []

  add: (socket, storage) ->
    wss = new WsSocket socket, @, storage
    @sockets.push wss

  remove: (id) ->
    sockets = @sockets
    found = no
    for let s, i in sockets
      if not found
        if id == s.id
          sockets.splice i, 1
          found := true
    INFO "ws[#{id}] disconnected."


module.exports = exports =
  name: NAME
  attach: (opts) ->
    {helpers} = opts
    module.logger = helpers.logger
    DBGT := -> module.logger.debug.apply module.logger, arguments
    INFO := -> module.logger.info.apply module.logger, arguments
    WARN := -> module.logger.warn.apply module.logger, arguments
    ERR := -> module.logger.error.apply module.logger, arguments
    module.manager = new WsManager opts
    return


  init: (done) ->
    {web, storage} = @
    manager = module.manager
    module.storage = storage

    # dependency check at initialization time
    return done new Error "#{exports.name.gray} depends on plugin #{'storage'.yellow} but missing" unless storage?
    return done new Error "#{exports.name.gray} depends on plugin #{'web'.yellow} but missing" unless web?

    web.useWs \storage, (socket) -> return manager.add socket, storage
    return done!

