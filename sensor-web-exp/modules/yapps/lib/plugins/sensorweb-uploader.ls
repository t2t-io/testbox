require! <[path colors moment fs zlib stream request]>
{sort} = require \prelude-ls

NAME = \sensorweb-uploader
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments
WARN = -> module.logger.warn.apply  module.logger, arguments
WORKDIR = ''
MAX_PACK_PERIOD = 10m * 60
# MIN_PACK_PERIOD = 5s
PACK_PERIOD_RATIO = 1.2


class Uploader
  (@opts) ->
    @data_map = {}
    @items = []
    @uploaded_at = moment!
    @uploading = no
    @uploaded_file = ""


  init: (@ttt_info, done) ->
    {timer} = @opts.helpers
    @pack_interval = @opts.pack_interval
    @pack_timer = new timer @pack_interval, @, \onPack
    @check_timer = new timer 5s, @, \onCheck
    @upload_timer = new timer 1s, @, \onUpload
    @pack_timer.start!
    @check_timer.start!
    @upload_timer.start!

    self = @
    {util} = self.opts.helpers
    {id, profile, profile_version} = ttt_info
    @id = id
    @profile = profile
    @profile_version = profile_version
    return util.createDirectories [WORKDIR], (err) ->
      return done err if err?
      done!


  onCheck: ->
    # Decide the pack interval depending on the number of cached
    # sensor data file
    #
    self = @
    fs.readdir WORKDIR, (err, files) ->
      return ERR err, "failed to list files at #{WORKDIR}" if err?
      num = files.length
      if num > 100
        new_interval = MAX_PACK_PERIOD
      else if num == 0
        new_interval = self.pack_interval
      else
        new_interval = self.pack_interval * Math.pow PACK_PERIOD_RATIO, num
        new_interval = if new_interval >= MAX_PACK_PERIOD then MAX_PACK_PERIOD else Math.round new_interval

      old_interval = self.pack_timer.getPeriod!
      if old_interval != new_interval
        self.pack_timer.configure new_interval
        t0 = "#{new_interval}"
        n0 = "#{num}"
        INFO "pack interval adjusted to #{t0.green} seconds (#{n0.yellow} cached files}"



  onData: (evt) ->
    {data, desc} = evt
    {board_type, board_id, sensor, data_type} = desc
    {value, last_value, updated_at, unit_length} = data
    p = "#{board_type}_#{board_id}_#{sensor}_#{data_type}"
    v = @data_map[p]

    if v?
      if value == v.data.value
        last_update = new moment v.data.updated_at
        now = new moment!
        last_update.add 30s, \seconds
        if now < last_update
          return false

    # return false if value == last_value and v?
    value = "#{value}#{unit_length}"
    last_value = "#{last_value}#{unit_length}"
    update = "#{updated_at}"
    DBGT "#{evt.desc.path.yellow} (mask: #{evt.evt.gray}): #{last_value.green} -> #{value.green}"
    @data_map[p] = evt
    @items.push evt


  onPack: ->
    items = @items
    @items = []
    return DBGT "No data to pack" if 0 == items.length

    data = id: @id, profile: @profile, items: items
    text = JSON.stringify data
    now = moment!
    p = @gzip_filename = "#{now.format 'YYYYMMDD_HHmmss'}.json.gz"

    self = @
    b = new Buffer text
    out = fs.createWriteStream "#{WORKDIR}#{path.sep}#{p}"
    out.on \close, -> self.gzip_filename = null  # indicate the file writing is finished.
    gzip = zlib.createGzip!
    input = new stream.PassThrough!
    input.end b
    input.pipe gzip .pipe out
    t1 = "#{b.length}"
    t2 = "#{items.length}"
    return INFO "#{p} written #{t1.green} bytes (#{t2.green} records)"


  onUpload: ->
    return false unless not @uploading
    now = moment!
    now.subtract @opts.upload_interval, \seconds
    return false if now < @uploaded_at

    ctx = self: @, next: no
    ae = new module.async-executor type: 'device', logger: DBGT, context: ctx

    tasks =
      * name: \find_file
        func: (AE, CTX, DBG, cb) ->
          {self} = CTX
          fs.readdir WORKDIR, (err, files) ->
            return cb err if err?
            items = []
            for let f, i in files
              if ".gz" == path.extname f
                items.push f

            if items.length == 0
              DBG "no sensor-data to be uploaded"
              return cb!

            items = sort items
            CTX.file = items.shift!
            CTX.file_number = items.length
            if CTX.file == CTX.self.gzip_filename
              DBG "last file is not closed yet"
              return cb!
            else
              CTX.next = yes
              return cb!

      * name: \upload
        func: (AE, CTX, DBG, cb) ->
          {next, file, self} = CTX
          return cb! unless next
          self.uploading = yes
          self.uploaded_at = moment!
          CTX.full_path = "#{WORKDIR}#{path.sep}#{file}"
          self.submitData \sensor-data, CTX.full_path, (err) ->
            if err?
              self.uploading = no
              return cb err
            else
              DBG "successfully upload #{file}"
              return cb!

      * name: \delete
        func: (AE, CTX, DBG, cb) ->
          {next, full_path, self, file} = CTX
          return cb! unless next
          fs.unlink full_path, (err) ->
            self.uploading = no
            return cb err if err?
            DBG "successfully delete #{file}"
            return cb!

    ae.series tasks, (executor, ctx, err, results) ->
      {next, file, self} = ctx
      if err?
        # self.configureInterval no
        return ERR err, "failed to process #{file}" if file?
        return ERR err, "failed to find sensor-data-file"
      else
        return DBGT "no sensor data to be uploaded" unless next
        # self.configureInterval yes
        return INFO "#{file} uploaded successfully"


  # Decide the pack interval depending on the success/failure of
  # sensor data uploading.
  #
  configureInterval: (upload_success) ->
    if upload_success
      t = "#{@pack_interval}"
      return DBGT "pack interval (#{t.green} seconds) is default value" if @pack_interval == MIN_PACK_PERIOD

      new_interval = @pack_interval / PACK_PERIOD_RATIO
      @pack_interval = if new_interval < MIN_PACK_PERIOD then MIN_PACK_PERIOD else new_interval

      t = "#{@pack_interval}"
      INFO "decrease pack interval to #{t.green} seconds"
      @pack_timer.configure Math.round @pack_interval

    else
      t = "#{@pack_interval}"
      return WARN "pack interval (#{t.green} seconds) is the maximum" if @pack_interval == MAX_PACK_PERIOD

      new_interval = @pack_interval * PACK_PERIOD_RATIO
      @pack_interval = if new_interval > MAX_PACK_PERIOD then MAX_PACK_PERIOD else new_interval

      t = "#{@pack_interval}"
      INFO "increase pack interval to #{t.green} seconds"
      @pack_timer.configure Math.round @pack_interval



  # Submit the gzipped sensor data onto hub.dhvac.io server
  #
  submitData: (type, file, done) ->
    {id, profile} = @
    {hub} = @opts
    url = "#{hub.base}/api/v#{hub.version}/hub/#{id}/#{profile}"
    # url = "#{hub.base}/api/v#{hub.version}/ttt/nodes/#{id}/#{type}/#{profile}"
    form_data = sensor_data_gz: fs.createReadStream file
    req = url: url, formData: form_data, auth: {user: \admin, pass: \abc}
    request.post req, (err, rsp, body) ->
      return done err if err?
      return done "unexpected return code: #{rsp.statusCode}" unless rsp.statusCode == 200
      return done null


module.exports = exports =
  name: NAME
  attach: (opts) ->
    {resource, async-executor} = opts.helpers
    WORKDIR := resource.resolveWorkPath 'work', NAME

    module.opts = opts
    module.logger = opts.helpers.logger
    module.async-executor = async-executor
    module.uploader = @uploader = new Uploader opts
    DBGT "attached"
    # MIN_PACK_PERIOD := opts.pack_interval


  init: (done) ->
    app = @
    {uploader} = module
    {ttt_info} = app

    # dependency check at initialization time
    return done new Error "#{exports.name.gray} depends on plugin #{'ttt_info'.yellow} but missing" unless ttt_info?

    app.on 'ssc::*::*::*::*', (evt) -> return uploader.onData evt
    return uploader.init ttt_info, (err) ->
      ERR "failed to initialize, err: #{err}" if err?
      return done err if err?
      DBGT "initialized"
      return done!

