require! <[express http fs path colors handlebars]>
require! <[body-parser express-bunyan-logger]>
{elem-index, keys} = require 'prelude-ls'
error_responses = require "#{__dirname}/web_errors"

NAME = \web
DBGT = null
INFO = null
ERR = null


composeError = (req, res, name, err = null) ->
  if error_responses[name]?
    r = error_responses[name]
    template = handlebars.compile r.message
    context = ip: req.ip, originalUrl: req.originalUrl, err: err
    msg = template context
    result =
      code: r.code
      error: name
      url: req.originalUrl
      message: msg
    ERR "#{req.method} #{colors.yellow req.url} #{colors.green name} json = #{JSON.stringify result}"
    res.status r.status .json result
  else
    ERR "#{colors.yellow req.url} #{colors.green name} json = unknown error"
    res.status 500 .json error: "unknown error: #{name}"


composeData = (req, res, data, code=200) ->
  result =
    code: 0
    error: null
    message: null
    url: req.originalUrl
    data: data
  res.status code .json result


# Middleware: initiate web_context variable
#
initiation = (req, res, next) ->
  req.web_context = {}
  next!


# Middleware: detect the client's ip address is trusted or not, and save result at web_context.trusted_ip
#
detectClientIp = (req, res, next) ->
  ip = req.ip
  web_context = req.web_context
  web_context.trusted_ip = false
  web_context.trusted_ip = true if ip == "127.0.0.1"
  web_context.trusted_ip = true if ip.startsWith "192.168."
  web_context.trusted_ip = true if undefined != elem-index ip, <[118.163.145.217 118.163.145.218 118.163.145.219 118.163.145.220 118.163.145.221 118.163.145.222 59.87.11.170]>
  next!


# Middleware: ensure only trusted ip to access the end-point
#
trusted_ip = (req, res, next) ->
  return composeError req, res, \untrusted_ip unless req.web_context.trusted_ip
  return next!


# Middleware: ensure only trusted ip or trusted user (via HTTP Basic Authentication) to access the end-point
#
trusted_ip_or_user = (req, res, next) ->
  # [todo] implement authentication with passport
  #
  # return module.auth req, res, next unless req.web_context.trusted_ip
  req.user = name: 'localhost'
  return next!


secretCurrying = (webserver, name, password, done) -->
  return webserver.secretCheck name, password, done



class WebServer
  (@opts, @app) ->
    DBGT "initiate"
    @web = null
    @routes = {}
    @api_routes = {}
    @wss = {}
    @sys_helpers = @opts.helpers
    {resource, util} = @sys_helpers

    # Prepare helper middlewares and functions
    @helpers =
      composeError: composeError
      composeData: composeData
      trusted_ip: trusted_ip
      trusted_ip_or_user: trusted_ip_or_user

    # Default options
    @_opts =
      upload_path: resource.resolveWorkPath 'work', 'web/upload'
      port: 6010
      host: \0.0.0.0
      headless: yes
      view_verbose: no
      api: 1
      express_partial_response: yes
      express_method_overrid: yes
      express_multer: yes

    # Replace with user's preferred options
    fields = keys @_opts
    @_opts = util.copyObject @_opts, @opts, fields

    # Directory for compiled assets (e.g. Livescript to Javascript)
    if not @_opts.headless
      @_opts.js_dest_path = resource.resolveWorkPath \work, 'web/dest'


  initiateLogger: ->
    {logger} = @sys_helpers
    web-middleware = express-bunyan-logger do
      logger: logger
      immediate: no
      levelFn: (status, err) ->
        return \debug if 200 == status
        return \debug if 201 == status
        return \debug if status >= 300 and status < 400
        return \info if status >= 400 and status < 500
        return \error if status >= 500
        return \warn

    @web.use web-middleware


  initiateView: ->
    return false if @_opts.headless
    {web, _opts} = @
    {resource} = @sys_helpers
    js_path = resource.resolveResourcePath \assets, \js
    img_path = resource.resolveResourcePath \assets, \img
    css_path = resource.resolveResourcePath \assets, \css
    jade_path = resource.resolveResourcePath \assets, \views
    favicon_path = resource.resolveResourcePath \assets, 'img/favicon.ico'
    livescript_path = resource.resolveResourcePath \assets, \ls
    js_dest_path = _opts.js_dest_path

    if fs.existsSync jade_path
      require! <[jade]>
      INFO "set view engine: jade (#{jade_path.cyan})"
      web.set 'views', jade_path
      web.set 'view engine', \jade
    else
      DBG "no view engine (the template directory #{jade_path.cyan} does not exist)"

    if fs.existsSync favicon_path
      require! <[serve-favicon]>
      web.use serve-favicon favicon_path
      INFO "set favicon (#{favicon_path.cyan})"
    else
      DBG "no favicon (the icon directory #{favicon_path.cyan} does not exist)"

    if fs.existsSync img_path
      web.use '/img', express.static img_path
      INFO "add /img"
    else
      DBG "no /img (#{img_path.cyan} does not exist)"

    if fs.existsSync css_path
      web.use '/css', express.static css_path
      INFO "add /css"
    else
      DBG "no /css (#{css_path.cyan} does not exist)"

    if fs.existsSync livescript_path
      livescript-middleware = require './livescript-middleware'
      compile = livescript-middleware do
        src: livescript_path
        dest: js_dest_path
      web.use '/js', compile, express.static js_dest_path
      INFO "add /js (with livescript-middleware)"
    else
      DBG "no compiled /js (#{livescript_path.cyan} does not exist)"

    if fs.existsSync js_path
      web.use '/js', express.static js_path
      INFO "add /js"
    else
      DBG "no raw /js (#{js_path.cyan} does not exist)"



  start: (done) ->
    DBGT "preparing middlewares ..."
    {resource} = @sys_helpers
    {port, host, upload_path} = @_opts
    @web = web = express!
    @server = http.createServer @web
    web.set 'trust proxy', true

    web.use body-parser.json!
    web.use body-parser.urlencoded extended: true
    DBGT "use middleware: body-parser"

    if @_opts.express_multer
      require! \multer
      web.use multer dest: upload_path
      DBGT "use middleware: multer"

    if @_opts.express_method_overrid
      require! \method-override
      web.use method-override!
      DBGT "use middleware: method-override"

    if @_opts.view_verbose
      @initiateLogger!
      @initiateView!
    else
      @initiateView!
      @initiateLogger!

    # My middlewares
    web.use initiation
    web.use detectClientIp

    # General routes from other plugins
    jade_path = web.get 'views'
    for let name, middleware of @routes
      web.use "/#{name}", middleware
      INFO "add /#{name}"
      if jade_path?
        middleware.set 'views', jade_path
        middleware.set 'view engine', \jade

    # API routes
    point = "/api/v#{@_opts.api}/"
    v = @api_v = new express!
    if @_opts.express_partial_response
      m = require \express-partial-response
      v.use m!
    INFO "using #{point} (partial-response: #{@_opts.express_partial_response})"


    for let name, middleware of @api_routes
      v.use "/#{name}", middleware
      INFO "add #{point}#{name}"

    api = @api = new express!
    api.use "/v#{@_opts.api}", v
    web.use "/api", api

    # Prepare Socket server and WebSocket
    sio = require \socket.io
    @io = sio @server
    @server.on 'listening', ->
      p = "#{port}"
      INFO "listening #{host.yellow}:#{p.cyan}"
      return done!

    # Register different handler for incoming web-sockets in different
    # namespace.
    #
    for let name, handler of @wss
      s = @io.of name
      s.on \connection, handler
      INFO "add handler for ws://localhost/#{name}"

    DBGT "starting web server ..."
    @server.listen port, host

  use: (name, middleware) -> return @routes[name] = middleware if not @web?
  useApi: (name, middleware) -> return @api_routes[name] = middleware if not @web?
  useWs: (name, handler) -> return @wss[name] = handler if not @web?



module.exports = exports =
  name: NAME
  attach: (opts) ->
    module.logger = opts.helpers.logger
    DBGT := -> module.logger.debug.apply module.logger, arguments
    INFO := -> module.logger.info.apply module.logger, arguments
    ERR := -> module.logger.error.apply module.logger, arguments
    @web = new WebServer opts, @


  init: (done) ->
    {web} = @
    {util} = web.sys_helpers
    {_opts} = web
    dirs = [_opts.upload_path]
    dirs.push _opts.js_dest_path unless _opts.headless

    util.createDirectories dirs, (err) -> return done err

