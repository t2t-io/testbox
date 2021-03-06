require! <[async colors uid]>

loggerCurrying = (executor, task_name, logger, message) -->
  # prefix = "[#{colors.gray executor.type}.#{colors.gray executor.id}.#{colors.gray task_name}]"
  # prefix = "#{executor.type}#{colors.gray '.'}#{executor.id}#{colors.gray '.'}#{task_name}"
  num = "#{executor.num}"
  id = "#{executor.id}-#{num}"
  prefix = "#{executor.type}[#{id.gray}].#{task_name}"
  text = "#{prefix} #{message}"
  return logger text if logger?
  return console.log text


runTaskCurrying = (executor, context, logger, task_name, func, cb) -->
  DBG = loggerCurrying executor, task_name, logger
  try
    func executor, context, DBG, (err, result) -> return cb err, result
  catch error
    DBG "#{error.stack.red}"
    return cb error, null


seriesEndCurrying = (executor, cb, err, results) --> return cb executor, executor.context, err, results



module.exports = exports = class AsyncExecutor
  (@options) ->
    {type, logger, context, id} = options if options?
    @context = if context? then context else {}
    @type = if type? then type else "unknown"
    @logger = if logger? then logger else console.log
    @id = if id? then id else uid!
    @num = 0

  series: (tasks, callback) ->
    new_funcs = []
    for let t, i in tasks
      func = runTaskCurrying @, @context, @logger, t.name, t.func
      new_funcs.push func

    end = seriesEndCurrying @, callback
    async.series new_funcs, end
    @num = @num + 1
