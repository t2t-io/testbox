require! <[path colors moment request fs extendify]>
require! io: \socket.io-client

NAME = \matrix-client
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments

popAttr = (obj, key) ->
  value = obj[key]
  delete obj[key]
  return value

class MatrixClient
  (@opts, @app) ->
    @enabled = yes

  init: (ttt_info, done) ->
    opts = @opts
    client = @
    ext = extendify!

    conf = ext {}, ttt_info

    @id = popAttr conf, \id
    @alias = popAttr conf, \alias
    @profile = popAttr conf, \profile
    @profile_version = popAttr conf, \profile_version
    @conf = conf
    data =
      alias: @alias
      profile: @profile
      profile_version: @profile_version
      system: conf

    INFO data, "data"
    done!

    # Update Node information to matrix server
    #
    request.post \
      url: "#{opts.url}/api/v1/ttt/nodes/#{@id}", \
      auth: {user: \admin, pass: \abc}, \
      json: yes, \
      body: data, \
      (err, rsp, body) ->
        ERR err, "failed to update node information" if err?
        DBGT "body = #{JSON.stringify body}"
        s = client.s = io "#{opts.url}/#{opts.namespace}"
        s.on \disconnect, -> client.onDisconnect.apply client, []
        s.on \connect, -> client.onConnect.apply client, []
        s.on \data, (data) -> client.onData.apply client, [data]
        s.on \msg, (data) -> client.onMessage.apply client, [data]
        s.on \cmd, (data) -> client.onCommand.apply client, [data]


  sendPacket: (channel, buf) ->
    if @connected
      @s.emit channel, buf
      INFO "send #{buf.length} bytes to matrix::#{channel}"
    else
      ERR "failed to send data to #{channel} due to disconnection"


  postData: (type, file, done) ->
    url = "#{@opts.url}/api/v1/ttt/nodes/#{@id}/#{type}/#{@profile}"
    form_data = sensor_data_gz: fs.createReadStream file
    req = url: url, formData: form_data, auth: {user: \admin, pass: \abc}
    request.post req, (err, rsp, body) ->
      return done err if err?
      return done "unexpected return code: #{rsp.statusCode}" unless rsp.statusCode == 200
      return done null


  onConnect: ->
    INFO "connected to #{@opts.url}"
    data = id: @id
    @connected = yes
    @s.emit "register", JSON.stringify data


  onDisconnect: ->
    INFO "disconnected"
    @connected = no


  onData: (buf) ->
    INFO "onData: buf = #{JSON.stringify buf}"

  onMessage: (buf) ->
    INFO "onMessage: buf = #{buf}"

  onCommand: (buf) ->
    text = "#{buf}"
    try
      data = JSON.parse text
      # DBGT "onCommand, data = #{JSON.stringify data, null, ' '}"
      @app.emit "mc::cmd::#{data.type}", data
    catch error
      ERR err, "onCommand, failed to parse #{text}"



module.exports = exports =
  name: NAME
  attach: (opts) ->
    module.logger = opts.helpers.logger
    module.matrix = @matrix = new MatrixClient opts, @
    DBGT "attached"


  init: (done) ->
    app = @
    {matrix, ttt_info} = app

    # dependency check at initialization time
    return done new Error "#{exports.name.gray} depends on plugin #{'ttt_info'.yellow} but missing" unless ttt_info?

    return matrix.init ttt_info, (err) ->
      ERR err, "failed to initialize matrix-client" if err?
      return done err
