require! <[path colors express backbone mkdirp fs async]>
{EventEmitter2} = require 'eventemitter2'
{map, filter, values} = require 'prelude-ls'

WORKDIR = null
NAME = \storage
DBGT = -> module.logger.debug.apply module.logger, arguments if module.logger?
INFO = -> module.logger.info.apply module.logger, arguments if module.logger?
ERR = -> module.logger.error.apply module.logger, arguments if module.logger?
WARN = -> module.warn.warn.apply module.logger, arguments if module.logger?


copyBackbone = (m, data, fields) ->
  for let f, i in fields
    if data[f]?
      m.set f, data[f]


SensorData = backbone.Model.extend do
  urlRoot: WORKDIR

  defaults: ->
    d =
      created_at: new Date!
      updated_at: new Date!
      last_value: 0
      value: 0
      type: \number
      unit_length: ''
      name: ''
    return d

  /*
  set: (attributes, options) ->
    # console.log "trying to set `#{typeof attributes}`, options = #{typeof options}"
    # console.log "trying to set `#{JSON.stringify attributes}`, options = #{JSON.stringify options}"
    v = @.get 'value'
    backbone.Model.prototype.set.apply @, arguments
    if \string == typeof attributes and \value == attributes
      @.set 'last_value', v
      @.set 'type', typeof options
      @.set 'updated_at', new Date!
      console.log "trying to set `#{attributes}` with value `#{options}`, also update last_value, type, and updated_at fields"
  */


helpers =
  listFiles: (dir, done) ->
    getStatCurrying = (file, cb) -->
      full_path = "#{dir}#{path.sep}#{file}"
      return fs.stat full_path, (err, stats) ->
        return cb err if err?
        d = name: file, stats: stats, full_path: full_path
        return cb null, d

    fs.readdir dir, (err, files) ->
      return done err if err?
      funcs = []
      for let f, i in files
        func = getStatCurrying f
        funcs.push func

      async.series funcs, (error, results) ->
        return done error if error?
        return done null, results



  writeJson: (m, options) ->
    myErrorCb = (err) -> return options.error err if options.error?
    mySuccessCb = -> return options.success! if options.success?
    return mySuccessCb! unless module.data_sync
    full_dir = "#{WORKDIR}#{path.sep}#{m.get 'id'}"
    full_path = "#{full_dir}#{path.sep}#{m.get 'name'}.json"
    data = JSON.stringify m.toJSON!, null, '  '
    DBGT "writing #{data.length} bytes to #{full_path}"
    fs.writeFile full_path, data, (err) ->
      return myErrorCb err if err?
      return mySuccessCb!


  fetchJson: (m, options) ->
    myErrorCb = (err) -> return options.error err if options.error?
    mySuccessCb = -> return options.success! if options.success?
    return mySuccessCb! unless module.data_sync
    full_dir = "#{WORKDIR}#{path.sep}#{m.get 'id'}"
    full_path = "#{full_dir}#{path.sep}#{m.get 'name'}.json"
    fs.exists full_path, (exists) ->
      if exists
        DBGT "#{full_path} exists"
        fs.readFile full_path, (err, data) ->
          return myErrorCb err if err?
          try
            text = "#{data}"
            d = JSON.parse text
            copyBackbone m, d, <[created_at updated_at last_value value type unit_length]>
            return mySuccessCb!
          catch exx
            ERR "failed to load #{full_path}, err: #{exx}"
            return myErrorCb exx
      else
        INFO "#{full_path} does not exist"
        mkdirp full_dir, (err) ->
          return myErrorCb err if err?
          data = JSON.stringify m.toJSON!, null, '  '
          fs.writeFile full_path, data, (err) ->
            return myErrorCb err if err?
            return mySuccessCb!


backbone.sync = (method, model, options) ->
  return helpers.writeJson model, options if "update" == method
  return helpers.fetchJson model, options if "read" == method
  return ERR "backbone.sync, unsupported method `#{method}`, model.id = #{model.get 'id'}"




class Storage extends EventEmitter2
  (@opts, @app) ->
    super wildcard: yes, delimiter: \::
    DBGT "storage initiate"
    @cached_data = {}


  generateKey: (board_type, board_id, sensor, data_type) ->
    return "#{board_type}_#{board_id}_#{sensor}_#{data_type}"


  existData: (board_type, board_id, sensor, data_type, done) ->
    full_path = "#{WORKDIR}#{path.sep}#{board_type}#{path.sep}#{board_id}#{path.sep}#{sensor}#{path.sep}#{data_type}.json"
    return fs.exists full_path, done


  getData: (board_type, board_id, sensor, data_type, done) ->
    cached_data = @cached_data
    key = @.generateKey board_type, board_id, sensor, data_type
    sensor_data = cached_data[key]
    DBGT "found #{key}" if sensor_data?
    return done null, sensor_data if sensor_data?

    id = "#{board_type}#{path.sep}#{board_id}#{path.sep}#{sensor}"
    sensor_data = new SensorData id: id, name: data_type
    sensor_data.fetch do
      success: ->
        DBGT "successfully load #{id} : #{data_type}, store it to memory cache with key: #{key}"
        cached_data[key] = sensor_data
        return done null, sensor_data

      error: (err) ->
        DBGT "failed to load #{id} : #{data_type}, due to error: #{err}, let's use default values"
        return done null, sensor_data
        # return done err


  updateData: (board_type, board_id, sensor, data_type, value, unit_length, done) ->
    self = @
    emitter = @
    @.getData board_type, board_id, sensor, data_type, (err, s) ->
      return done err if err?
      v = s.get \value
      s.set \last_value, v
      s.set \updated_at, new Date!
      s.set \unit_length, unit_length
      s.set \type, typeof value
      s.set \value, value
      s.save! if module.data_sync

      done!
      return process.nextTick ->
        event_desc = board_type: board_type, board_id: board_id, sensor: sensor, data_type: data_type
        names = values event_desc
        names = <[storage]> ++ names
        event_desc[\path] = "#{path.sep}#{board_type}#{path.sep}#{board_id}#{path.sep}#{sensor}#{path.sep}#{data_type}"
        return emitter.emit names, event_desc, s.toJSON!


  list: (dir, is_dir, done) ->
    return fs.exists dir, (exists) ->
      return done "no such directory: #{dir}" unless exists
      return helpers.listFiles dir, (err, items) ->
        return done err if err
        results = []
        for let ii, i in items
          results.push ii.name if is_dir and ii.stats.isDirectory!
          results.push ii.name if not is_dir and ii.stats.isFile!
        return done null, results


  listBoardTypes: (done) ->
    return @.list WORKDIR, yes, done

  listBoardIds: (board_type, done) ->
    return @.list "#{WORKDIR}#{path.sep}#{board_type}", yes, done

  listSensors: (board_type, board_id, done) ->
    return @.list "#{WORKDIR}#{path.sep}#{board_type}#{path.sep}#{board_id}", yes, done

  listDataTypes: (board_type, board_id, sensor, done) ->
    return @.list "#{WORKDIR}#{path.sep}#{board_type}#{path.sep}#{board_id}#{path.sep}#{sensor}", no, (err, files) ->
      return done err if err
      results = []
      for let f, i in files
        if f != "metadata.json" and f.endsWith ".json"
          results.push path.basename f, '.json'
      return done null, results


module.exports = exports =
  name: NAME
  attach: (opts) ->
    {helpers} = opts
    {resource} = helpers
    module.logger = helpers.logger
    module.data_sync = opts.data_sync
    WORKDIR := resource.resolveWorkPath 'work', NAME

    DBGT "initialized"
    @storage = module.storage = new Storage opts, @


  init: (done) ->
    {storage} = @
    {util} = storage.opts.helpers

    DBGT "trying to create #{WORKDIR} if missing ..."
    util.createDirectories [WORKDIR], (err) -> return done err
