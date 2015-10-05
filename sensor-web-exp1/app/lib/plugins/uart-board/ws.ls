require! io: \socket.io-client


module.exports = exports = class Communicator
  (@index, @name, @bearer, @url_tokens, @opts, @logger) ->
    @index = "#{index}"
    @logger.debug "initiated"
    @verbose = yes

  setVerbose: (v) ->
    @verbose = v

  start: ->
    {logger, name, index, bearer, verbose, cb} = @
    {host, hostname, path} = @url_tokens
    u = @location = "http://#{host}#{path}"
    s = @socket = io u

    s.on \disconnect, ->
      logger.info "[#{index.cyan}].#{name} disconnected from #{u.yellow}"

    s.on \connect, ->
      logger.info "[#{index.cyan}].#{name} connected to #{u.yellow}"
      control = cmd: \config, params: {name: \data, value: true}
      s.emit \control, JSON.stringify control

    s.on \data, (data) ->
      line = "#{data}"
      cb hostname, name, bearer, line if cb?
      logger.debug "[#{index.cyan}].#{name} line = #{line}" if verbose


  setDataListener: (cb) ->
    @cb = cb


