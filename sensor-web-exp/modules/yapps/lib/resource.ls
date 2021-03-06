# Resource module.
#
#   - auto detect work_dir with following search order
#
#     1. $WORK_DIR/config       => process.env['WORK_DIR']
#     2. ./config               => path.resolve('.')
#     3. $(dirname $0)/config   => path.dirname(process.argv[1])
#
#
require! <[fs path]>

settings =
  program_name: null
  app_dir: null
  work_dir: null
  config_dir: null

DEBUG = (message) -> if process.env.VERBOSE then console.error message

CHECK = (p) ->
  config_dir = path.resolve "#{p}#{path.sep}config"
  log_dir = path.resolve "#{p}#{path.sep}logs"
  DEBUG "checking #{path.resolve p}"
  try
    dirs = fs.readdirSync config_dir
    if not fs.existsSync log_dir then fs.mkdirSync log_dir
    settings.work_dir = p
    settings.config_dir = config_dir
    console.log "use #{path.resolve p} as work_dir"
    console.log "use #{settings.app_dir} as app_dir"
  catch error
    DEBUG "checking #{path.resolve p} but failed"


# Setup the default program name.
#
if process.argv[1]?
  settings.program_name = path.basename process.argv[1]
else
  settings.program_name = "unknown"

# Setup the default app directory.
#
if process.argv[1]?
  settings.app_dir = path.dirname process.argv[1]
else
  settings.app_dir = process.cwd!


# 1.Check process.env['WORK_DIR'] can be used as work_dir
#
if process.env['WORK_DIR']? then CHECK process.env['WORK_DIR']

# 2. Check current dir.
#
if not settings.work_dir then CHECK path.resolve "."

# 3. Check process.argv[1] can be used as work_dir
#
# typically, the process.argv are as follows when executing `~/Downloads/test0.ls`
#   argv[0] = /opt/boxen/nodenv/versions/v0.10/bin/lsc
#   argv[1] = /Users/yagamy/Downloads/test0.ls
#
if not settings.work_dir and process.argv[1]? then CHECK path.dirname process.argv[1]

# If there is still no work_dir available to use, then terminate
# the current process immediately with error exit code.
#
if not settings.work_dir
  console.error "failed to find any work directory."
  if not process.env.VERBOSE? then console.error "please re-run the program with environment variable VERBOSE=true to get further verbose messages..."
  process.exit 1



LOAD_CONFIG = (p, callback) ->
  found = false
  try
    config = if p.json then JSON.parse fs.readFileSync p.path else require p.path
    found = true
    callback null, config
  catch error
    DBG "failed to load #{p.path} due to error: #{error}"

  return found


resource =

  /**
   * Dump all enviroment variables
   */
  dumpEnvs: ->
    for let v, i in process.argv
      DBG "argv[#{i}] = #{v}"
    DBG "process.execPath = #{process.execPath}"
    DBG "process.arch = #{process.arch}"
    DBG "process.platform = #{process.platform}"
    DBG "process.cwd() = #{process.cwd!}"
    DBG "path.normalize('.') = #{path.normalize '.'}"
    DBG "path.normalize(__dirname) = #{path.normalize __dirname}"
    DBG "path.resolve('.') = #{path.resolve '.'}"
    DBG "path.resolve(__dirname) = #{path.resolve __dirname}"

  /**
   * Load configuration file from following files in order
   *   - ${config_dir}/${name}.ls
   *   - ${config_dir}/${name}.js
   *   - ${config_dir}/${name}.json
   *
   * @param name, the name of configuration file to be loaded.
   */
  loadConfig: (name, callback) ->
    global.tmp = found: false
    pathes =
      * path: "#{settings.config_dir}#{path.sep}#{name}.ls"
        json: false
      * path: "#{settings.config_dir}#{path.sep}#{name}.js"
        json: false
      * path: "#{settings.config_dir}#{path.sep}#{name}.json"
        json: true

    for let p, i in pathes
      if not global.tmp.found then global.tmp.found = LOAD_CONFIG p, callback

    if not global.tmp.found then return callback "cannot find config #{name}", null


  /**
   * Resolve to an absolute path to the file in the specified
   * `type` directory, related to work_dir.
   *
   * @param type, the type of directory, e.g. 'logs', 'scripts', ...
   * @param filename, the name of that file.
   */
  resolveWorkPath: (type, filename) ->
    return path.resolve "#{settings.work_dir}#{path.sep}#{type}#{path.sep}#{filename}"


  /**
   * Resolve to an absolute path to the file in the specified
   * `type` directory, related to app_dir.
   *
   * @param type, the type of directory, e.g. 'logs', 'scripts', ...
   * @param filename, the name of that file.
   */
  resolveResourcePath: (type, filename) ->
    ret = path.resolve "#{settings.app_dir}#{path.sep}#{type}#{path.sep}#{filename}"
    # console.log "#{settings.app_dir}, #{type}, #{filename}, #{ret}"
    return ret

  /**
   * Load javascript, livescript, or coffeescript from ${app_dir}/lib. For example,
   * when `loadScript 'foo'` is called, the function tries to load scripts one-by-one
   * as following order:
   *
   *    1. ${app_dir}/lib/foo.js
   *    2. ${app_dir}/lib/foo.ls
   *
   * @name {[type]}
   */
  loadScript: (name) ->
    return require "#{settings.app_dir}#{path.sep}lib#{path.sep}#{name}"

  /**
   * Load javascript, livescript, or coffeescript from ${app_dir}/lib/plugins. For example,
   * when `loadPlugin 'foo'` is called, the function tries to load scripts one-by-one
   * as following order:
   *
   *    1. ${app_dir}/lib/plugins/foo.js
   *    2. ${app_dir}/lib/plugins/foo.ls
   *    3. ${app_dir}/lib/plugins/foo/index.js
   *    4. ${app_dir}/lib/plugins/foo/index.ls
   *    5. ${esys_modules}/base/lib/plugins/foo.js
   *    6. ${esys_modules}/base/lib/plugins/foo.ls
   *    7. ${esys_modules}/base/lib/plugins/foo/index.js
   *    8. ${esys_modules}/base/lib/plugins/foo/index.ls
   *
   * @name {[type]}
   */
  loadPlugin: (name) ->
    lib = \lib
    plugins = \plugins
    errors = []
    pathes =
      * "#{settings.app_dir}#{path.sep}#{lib}#{path.sep}#{plugins}#{path.sep}#{name}"
      * "#{settings.app_dir}#{path.sep}#{lib}#{path.sep}#{plugins}#{path.sep}#{name}#{path.sep}index"
      * "#{__dirname}#{path.sep}#{plugins}#{path.sep}#{name}"
      * "#{__dirname}#{path.sep}#{plugins}#{path.sep}#{name}#{path.sep}index"

    found = no
    m = null

    for let p, i in pathes
      if not found
        try
          m := require p
          found := yes
        catch error
          exx = err: error, path: p
          errors.push exx

    return m if found

    for let exx, i in errors
      DBG "loading #{exx.path} but err: #{exx.err}"

    exx = errors.pop!
    throw exx.err


  /**
   * Get the program name of entry javascript (livescript) for
   * nodejs to execute.
   */
  getProgramName: -> return settings.program_name

  getAppDir: -> return settings.app_dir
  getWorkDir: -> return settings.work_dir

module.exports = exports = resource