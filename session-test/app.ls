#!/usr/bin/env lsc
#
require! <[express pug]>
livescript-middleware = require \./src/livescript-middleware
session = require \express-session
SFS = (require \session-file-store) session
sfs-opts =
  path: \./work/sessions

const PORT = 7000
const SESSION_MAX_AGES = 5m*60s*1000ms

app = express!
app.set 'trust proxy', yes
app.set 'view engine', \pug
app.set 'views', "#{__dirname}/assets/views"

app.use session do
  store: new SFS sfs-opts
  secret: \keyboard
  resave: no
  saveUninitialized: no
  cookie:
    secure: yes
    expires: new Date (Date.now! + SESSION_MAX_AGES)
    maxAge: SESSION_MAX_AGES

app.use livescript-middleware src: "#{__dirname}/assets/scripts", dest: "#{__dirname}/work/js", compress: yes
app.use '/css', express.static "#{__dirname}/assets/public/css"
app.use '/js', express.static "#{__dirname}/work/js"
app.use '/js', express.static "#{__dirname}/assets/public/js"

app.use express.urlencoded extended:yes
app.use express.json!

app.get '/', (req, res) ->
  {session} = req
  if session.views?
    session.views = session.views + 1
    res.setHeader \Content-Type, \text/html
    {views, cookie} = session
    {maxAge} = cookie
    title = \hello
    res.render \login, {views, maxAge, title}
    # res.write "<p>views: #{session.views}</p>"
    # res.write "<p>expires in: #{session.cookie.maxAge}s</p>"
    # res.end!
  else
    session.views = 1
    res.end "Welcome to the file session demo. Refresh page!"

app.get '/login', (req, res) ->
  {session} = req
  session.views = session.views + 1
  res.setHeader \Content-Type, \text/html
  {views, cookie} = session
  {maxAge} = cookie
  title = \Login
  res.render \login, {session, title}

app.post '/actions/login', (req, res) ->
  console.log "login => #{JSON.stringify req.body}"
  res.send "/actions/login"

app.post '/actions/register', (req, res) ->
  console.log "register => #{JSON.stringify req.body}"
  res.send "/actions/register"

server = app.listen PORT, ->
  console.log "listening #{PORT}"