require! <[path colors express]>

NAME = \storage-webapi
DBGT = null



module.exports = exports =
  name: NAME
  attach: (opts) ->
    {helpers} = opts
    module.logger = helpers.logger
    DBGT := -> module.logger.debug.apply module.logger, arguments
    return


  init: (done) ->
    {web, logger, storage} = @
    # dependency check at initialization time
    return done new Error "#{exports.name.gray} depends on plugin #{'web'.yellow} but missing" unless web?
    return done new Error "#{exports.name.gray} depends on plugin #{'storage'.yellow} but missing" unless storage?
    return done new Error "#{exports.name.gray} depends on plugin #{'logger'.yellow} but missing" unless logger?

    {composeError, composeData, trusted_ip_or_user} = web.helpers

    s = module.s = new express!
    s.use trusted_ip_or_user

    s.get '/hello', (req, res) ->
      return composeData req, res, hello: \world

    s.post '/', (req, res) ->
      data = req.body
      DBGT "/: data = #{JSON.stringify data}"
      logger.enable data.logger if data[\logger]?
      return composeData req, res, "done"

    # List all types of board
    #
    s.get '/', (req, res) ->
      storage.listBoardTypes (err, types) ->
        return composeError req, res, \general_server_error, err if err
        return composeData req, res, types: types, metadata: {}


    # List all available boards (its `id`) of the specified board_type.
    #
    s.get '/:board_type/', (req, res) ->
      {board_type} = req.params
      storage.listBoardIds board_type, (err, ids) ->
        return composeError req, res, \general_server_error, err if err
        return composeData req, res, boards: ids, metadata: {}


    # List all sensors of one board
    #
    s.get '/:board_type/:board_id/', (req, res) ->
      {board_type, board_id} = req.params
      storage.listSensors board_type, board_id, (err, sensors) ->
        return composeError req, res, \general_server_error, err if err
        return composeData req, res, sensors: sensors, metadata: {}


    # List all types of data captured by the specificed sensor
    #
    s.get '/:board_type/:board_id/:sensor', (req, res) ->
      {board_type, board_id, sensor} = req.params
      storage.listDataTypes board_type, board_id, sensor, (err, types) ->
        return composeError req, res, \general_server_error, err if err
        return composeData req, res, types: types, metadata: {}


    # Get the latest value of data for one type of the specified sensor
    #
    s.get '/:board_type/:board_id/:sensor/:data_type', (req, res) ->
      {board_type, board_id, sensor, data_type} = req.params
      storage.existData board_type, board_id, sensor, data_type, (exists) ->
        return composeError req, res, \general_server_error, "no such data" unless exists
        data = storage.getData board_type, board_id, sensor, data_type, (err, data) ->
          return composeError req, res, \general_server_error, err if err
          return composeData req, res, data.toJSON!


    # Update the latest value of data for one type of specified sensor
    #
    s.post '/:board_type/:board_id/:sensor/:data_type', (req, res) ->
      {board_type, board_id, sensor, data_type} = req.params
      {value, unit_length} = req.body
      return composeError req, res, \missing_field, \value unless value?
      unit_length = '' unless unit_length?
      storage.updateData board_type, board_id, sensor, data_type, value, unit_length, (err) ->
        return composeError req, res, \general_server_error, err if err
        return composeData req, res, {}


    @web.useApi \s, s
    return done!
