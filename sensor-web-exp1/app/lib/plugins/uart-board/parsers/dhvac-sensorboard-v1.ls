NAME = \dhvac-sensorboard-v1
PROTOCOL_SPEC =
  * name: \st-hts221
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

  * name: \iaq-core-p
    types:
      * prefix: \O
        name: \co2
        unit_length: \ppm
        range: {low: 0, high: 10000}
        parse: parseInt

      * prefix: \V
        name: \voc
        unit_length: \ppb
        range: {low: 0, high: 10000}
        parse: parseFloat

  * name: \st-lps25h
    types: [
      * prefix: \P
        name: \pressure
        unit_length: \hPa
        range: {low: 0, high: 10000}
        parse: parseFloat
    ]

  * name: \ds-t-110
    types: [
      * prefix: \C
        name: \co2
        unit_length: \ppm
        range: {low: 0, high: 10000}
        parse: parseInt
    ]

  * name: \als-pt19-315c
    types: [
      * prefix: \L
        name: \light
        unit_length: \Lux
        range: {low: 0, high: 1000.0}
        parse: parseFloat

    ]

  * name: \gp2y1010au
    types: [
      * prefix: \D
        name: \dust
        unit_length: \µg/m^3
        range: {low: 0, high: 1000.0}
        parse: parseFloat
    ]

  * name: \temp
    types: [
      * prefix: \S
        name: \sound
        unit_length: \db
        range: {low: 0, high: 100.0}
        parse: parseInt
    ]


module.exports = exports = class Handler
  (@board_type, @board_id, @opts, @logger) -> return

  getSpec: -> return PROTOCOL_SPEC


  processData: (sensor, type_spec, value, updateFunc) ->
    {name, unit_length} = type_spec
    return updateFunc @board_type, @board_id, sensor, name, value, unit_length


  setVerbose: (@verbose) -> return


  # Filter-out some exceptional values
  #
  preprocessData: (sensor, type_spec, value) ->
    err_codes =
      * name: \communication_error
        value: -32768
      * name: \value_error
        value: -32767
      * name: \device_is_busy
        value: -32766
      * name: \device_error
        value: -32765
      * name: \device_booting
        value: -32764

    found = no
    name = ''
    for let ec, i in err_codes
      if not found
        if ec.value == value
          found := yes
          name := ec.name

    return true unless found

    text = "#{value}"
    @logger.error "#{sensor.yellow}/#{type_spec.name.yellow}: #{name.red} (#{text.cyan})" if @verbose
    return false
