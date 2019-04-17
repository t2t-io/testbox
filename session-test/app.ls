#!/usr/bin/env lsc
#
require! <[crypto]>
require! <[express pug mysql uuid]>
livescript-middleware = require \./src/livescript-middleware
email = require \emailjs
session = require \express-session
SFS = (require \session-file-store) session
sfs-opts =
  path: \./work/sessions

const PORT = 7000
const SESSION_MAX_AGES = 5m*60s*1000ms
const SALT = 'ilovetty'
const MAILER = 'ultron@t2t.io'
const HOST = "https://nuc54250b.t2t.io"


pool = global.pool = mysql.createPool do
  connectionLimit: 5
  host: \127.0.0.1
  user: \root
  password: \root
  database: \aaa


mailsrv = email.server.connect do
  user: MAILER
  password: \5gwifi4t2t
  host: \smtp.gmail.com
  ssl: yes

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

app.use livescript-middleware src: "#{__dirname}/assets/scripts", dest: "#{__dirname}/work/js"
app.use '/css', express.static "#{__dirname}/assets/public/css"
app.use '/js', express.static "#{__dirname}/work/js"
app.use '/js', express.static "#{__dirname}/assets/public/js"

app.use express.urlencoded extended:yes
app.use express.json!

app.get '/', (req, res) ->
  {session} = req
  res.setHeader \Content-Type, \text/html
  {user} = session
  if user?
    res.render \control, {user}
  else
    title = \login
    res.render \login, {title}

app.get '/views/login', (req, res) ->
  {session} = req
  session.views = session.views + 1
  res.setHeader \Content-Type, \text/html
  {views, cookie} = session
  {maxAge} = cookie
  title = \Login
  res.render \login, {session, title}

app.get '/views/control', (req, res) ->
  {session} = req
  res.setHeader \Content-Type, \text/html
  {user} = session
  if user?
    res.render \control, {user}
  else
    title = \login
    res.render \login, {title}

app.post '/actions/register', (req, res) ->
  {body} = req
  console.log "register => #{JSON.stringify body}"
  {name, email, password} = body
  pswdhash = ((crypto.createHmac 'sha256', SALT).update password .digest 'hex')
  activation = uuid! .split '-' .join ''
  agent = uuid! .split '-' .join ''
  api = uuid! .split '-' .join ''
  documentation = JSON.stringify {aa: 10, bb: yes, cc: 1.1, dd: "aa"}
  updated_by = "root"
  updated_from = req.ip
  (err, connection) <- pool.getConnection
  return res.send "err: #{err}" if err?
  console.log "#{req.originalUrl}: get connection"
  user = {email, name, pswdhash, activation, agent, api, documentation, updated_by, updated_from}
  connection.query 'INSERT INTO Users SET ?', user, (error, results, fields) ->
    if error?
      res.send "err: #{error}" if error?
      return connection.release!
    connection.release!
    user.id = results.insertId
    req.session.user = user
    res.render \control, {user}
    mailsrv.send do
      from: MAILER
      to: email
      bcc: MAILER
      subject: "Welcome to Wstty Service"
      text: """
      Dear #{name},

      Thanks for register wstty service. Please click #{HOST}/actions/activate/#{activation} to activate your user account. Thanks.

      Best Regards,
      Wstty Service Team
      """

app.get '/actions/activate/:activation', (req, res) ->
  {params} = req
  {activation} = params
  updated_by = "root"
  updated_from = req.ip
  (err, connection) <- pool.getConnection
  return res.send "err: #{err}" if err?
  console.log "#{req.originalUrl}: get connection"
  (error1, results, fields) <- connection.query 'SELECT * FROM `Users` WHERE activation = ?', [activation]
  if error1?
    console.log "#{req.originalUrl}: error1 => #{error1}"
    res.send "error: #{error1}"
    return connection.release!
  if results.length is 0
    console.log "#{req.originalUrl}: no such activation token #{activation}"
    res.send "no such activation token #{activation}"
    return connection.release!
  user = req.session.user = results[0]
  (error2, results, fields) <- connection.query 'UPDATE `Users` SET activated = 1 WHERE id = ?', [user.id]
  if error2?
    console.log "#{req.originalUrl}: error2 => #{error2}"
    res.send "error: #{error2}"
    return connection.release!
  res.setHeader \Content-Type, \text/html
  res.render \after_activation, {user}
  return connection.release!


server = app.listen PORT, ->
  console.log "listening #{PORT}"
