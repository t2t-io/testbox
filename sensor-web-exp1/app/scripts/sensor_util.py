import copy

class SensorData:
    def __init__(self, board_type='', board_id='', sensor='', data_type='', value=0, unit_length=None):
        self._data = {}
        self.board_type = board_type
        self.board_id = board_id
        self.sensor = sensor
        self.data_type = data_type
        self.value = value
        self.unit_length = unit_length

    @property
    def board_type(self):
        return self._data['board_type']

    @property
    def board_id(self):
        return self._data['board_id']

    @property
    def sensor(self):
        return self._data['sensor']

    @property
    def data_type(self):
        return self._data['data_type']

    @property
    def value(self):
        return self._data['value']

    @property
    def unit_length(self):
        return self._data['unit_length']

    @board_type.setter
    def board_type(self, v):
        self._data['board_type'] = v

    @board_id.setter
    def board_id(self, v):
        self._data['board_id'] = v

    @sensor.setter
    def sensor(self, v):
        self._data['sensor'] = v

    @data_type.setter
    def data_type(self, v):
        self._data['data_type'] = v

    @value.setter
    def value(self, v):
        self._data['value'] = v

    @unit_length.setter
    def unit_length(self, v):
        self._data['unit_length'] = v


    def __repr__(self):
        return self.to_line(" ")


    def to_line(self, separator="\t"):
        data = self._data
        orders = ['board_type', 'board_id', 'sensor', 'data_type', 'value', 'unit_length']
        tokens = [ str(data[v]) for v in orders if data[v] is not None ]
        return separator.join(tokens)


    def duplicate(self, board_type=None, board_id=None, sensor=None, data_type=None, value=None, unit_length=None):
        x = copy.deepcopy(self)
        x.board_type = board_type if board_type is not None else x.board_type
        x.board_id = board_id if board_id is not None else x.board_id
        x.sensor = sensor if sensor is not None else x.sensor
        x.data_type = data_type if data_type is not None else x.data_type
        x.value = value if value is not None else x.value
        x.unit_length = unit_length if unit_length is not None else x.unit_length
        return x


