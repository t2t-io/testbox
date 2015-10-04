NAME = \yasai-arduino-v1
PROTOCOL_SPEC =
  * name: \k30
    types: [
      * prefix: \C
        name: \co2
        unit_length: \ppm
        range: {low: 0, high: 10000}
        parse: parseInt
      ]

  * name: \rht30
    types:
      * prefix: \H
        name: \humidity
        unit_length: \%rH
        range: {low: 0, high: 100.0}
        parse: parseFloat

      * prefix: \T
        name: \temperature
        unit_length: \°C
        range: {low: -40.0, high: 80.0}
        parse: parseFloat

  * name: \ds18b20    # water-temperature
    types: [
      * prefix: \W
        name: \temperature
        unit_length: \°C
        range: {low: -55.0, high: +125.0}
        parse: parseFloat
    ]

  * name: \tt-arya
    types:
      * prefix: \X
        name: \water-level
        unit_length: ''
        range: {low: 0, high: 1}
        parse: parseInt

      * prefix: \F
        name: \fan
        unit_length: \%
        range: {low: 0, high: 100}
        parse: parseInt

      * prefix: \L
        name: \led
        unit_length: ''
        range: {low: 0, high: 129}
        parse: parseInt

      * prefix: \U
        name: \pump
        unit_length: ''
        range: {low: 0, high: 1}
        parse: parseInt

      * prefix: \A
        name: \led-array
        unit_length: ''
        range: {low: 0, high: 163}
        parse: parseInt

      * prefix: \N
        name: \state
        unit_length: ''
        range: {low: 0, high: 1}
        parse: parseInt


module.exports = exports = class Handler
  (@board_type, @board_id, @opts, @logger) -> return

  getSpec: -> return PROTOCOL_SPEC


  processData: (sensor, type_spec, value, updateFunc) ->
    {name, unit_length} = type_spec
    if \led == type_spec.name
      led = if value >= 128 then 0 else 1
      led-brightness = value
      updateFunc @board_type, @board_id, sensor, \led, led
      updateFunc @board_type, @board_id, sensor, \led-brightness, led-brightness
    else if \fan == type_spec.name
      fan = if value > 0 then 1 else 0
      fan-speed = value
      updateFunc @board_type, @board_id, sensor, \fan, fan
      updateFunc @board_type, @board_id, sensor, \fan-speed, fan-speed
    else
      return updateFunc @board_type, @board_id, sensor, name, value, unit_length


  # Dummpy implementation
  #
  preprocessData: (sensor, type_spec, value) -> return true

  setVerbose: (@verbose) -> return
