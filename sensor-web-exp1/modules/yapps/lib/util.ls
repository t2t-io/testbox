require! <[mkdirp async]>

util =
  # Create multiple directories
  #
  createDirectories: (dirs, callback) ->
    funcs = []
    createCurrying = (dir, cb) -->
      DBG "creating #{dir} ..."
      return mkdirp dir, (err) -> 
        return cb err

    for let dir, i in dirs
      c = createCurrying dir
      funcs.push c

    async.series funcs, (err, results) -> return callback err


  copyObject: (dst, src, fields) -> 
    for let f, i in fields
      if src[f]?
        dst[f] = src[f]
    return dst


module.exports = exports = util