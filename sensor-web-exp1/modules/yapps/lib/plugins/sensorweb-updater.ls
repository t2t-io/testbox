# SensorWeb-Updater
#
# PURPOSE:
#   The plugin listens `sensorweb-updater::*::*::*::*` event with sesnro data, and upload the data
#   onto SensorWeb server via HTTP POST.
#
#   The event callback function has 2 arguments:
#     - `evt`, composed of these fields: board_type, board_id, sensor, data_type
#     - `data`, composed of these fields: last_value, unit_length, last_update
#
require! <[path colors request]>

NAME = \sensorweb-updater
DBGT = -> module.logger.debug.apply module.logger, arguments
INFO = -> module.logger.info.apply  module.logger, arguments
ERR  = -> module.logger.error.apply module.logger, arguments


module.exports = exports =
  name: NAME
  attach: (opts) ->
    module.opts = opts
    module.logger = opts.helpers.logger

  init: (done) ->
    {port, host, api} = module.opts
    port = 6020 unless port?
    host = \0.0.0.0 unless host?
    api = \1 unless api?
    app = @
    app.on 'sensorweb-updater::*::*::*::*', (evt, data) ->
      {board_type, board_id, sensor, data_type} = evt
      {last_value, unit_length} = data
      body = value: last_value, unit_length: unit_length
      url = "http://#{host}:#{port}/api/v#{api}/s/#{board_type}/#{board_id}/#{sensor}/#{data_type}"
      request.post url: url, json: yes, body: body, (err, rsp, body) ->
        return ERR "failed to post #{last_value}#{unit_length} to #{url}, err: #{err}" if err?
        return ERR "failed to post #{last_value}#{unit_length} to #{url}, code: #{rsp.statusCode}" unless 200 == rsp.statusCode
        return DBGT "successful to post #{last_value}#{unit_length} to #{url}"

    done!

