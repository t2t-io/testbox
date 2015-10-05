require! <[net byline]>

CHECK_INTERVAL = 2000ms


module.exports = exports = class Communicator
  (@index, @name, @bearer, @url_tokens, @opts, @logger) ->
    @index = "#{index}"
    @logger.debug "initiated"
    @verbose = yes
    @client = null
    @reader = null
    @connected = no


  setVerbose: (v) ->
    @verbose = v


  setDataListener: (cb) ->
    @cb = cb


  startConnection: ->
    self = @
    {logger, name, index, bearer, verbose, cb} = self
    {host, hostname, port} = @url_tokens
    @client = new net.Socket!
    @client.on \error, (err) -> self.onError.apply self, [err]
    @client.on \close, -> self.onClose.apply self, []
    @client.connect port, hostname, -> self.onConnected.apply self, []

    # Start a regular timer to check whether tcp connection is alive or not
    #
    check = -> return self.onCheck.apply self, []
    setInterval check, CHECK_INTERVAL


  start: ->
    return @.startConnection!


  onCheck: ->
    return @.startConnection! if @client == null and not @connected


  onError: (error) ->
    {host, hostname, port} = @url_tokens
    @logger.error "failed to connect #{host.yellow}, err: #{error}"
    @.cleanup!


  onConnected: ->
    {name, bearer, cb, logger, verbose} = @
    {host, hostname, port} = @url_tokens
    @logger.info "connected to #{host.yellow}"
    @connected = yes
    @reader = byline @client
    @reader.on \data, (data) ->
      line = "#{data}"
      # logger.info "line = #{line.green}" if verbose
      return cb hostname, name, bearer, line if cb?


  onClose: ->
    {host, hostname, port} = @url_tokens
    @logger.info "disconnected to #{host.yellow}"
    @.cleanup!


  cleanup: ->
    if @reader?
      @reader.removeAllListeners \data
      @reader = null

    if @client?
      @client.removeAllListeners \error
      @client.removeAllListeners \close
      @client = null

    @connected = no


