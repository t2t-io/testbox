#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
import re
import os

# Helper classes and functions
#
from sensor_util import SensorData

class BaseSensor:
    def __init__(self):
        self._base = SensorData()
        self._last_data = []
        self._unit_length_defs = {}
        self._exclusive_list = []
        self._preferred_period = None    # preferred period to perform measurement: 1 second
        self._default_period = 1
        pass

    def measure(self):
        # always need to implement
        pass

    def filter(self, props):
        elist = set(self._exclusive_list)
        key_values = [ (k, v) for k, v in props.items() if k not in elist ]
        return dict(key_values)

    def transform(self, props):
        return props

    def produce(self, data_type, value):
        defs = self._unit_length_defs
        u = defs[data_type] if data_type in defs else None
        return self._base.duplicate(data_type=data_type, value=value, unit_length=u)

    def get_classname_tokens(self):
        name = self.__class__.__name__
        return re.findall(r'[A-Z](?:[a-z]+|[A-Z]*(?=[A-Z]|$))', name)

    def get_upper_classname_tokens(self):
        return [ x.upper() for x in self.get_classname_tokens() ]

    @property
    def preferred_period(self):
        p = 1 if self._preferred_period is None else self._preferred_period
        v = None
        tokens = self.get_upper_classname_tokens()
        tokens = [ 'SYS_STATS' ] + tokens + [ 'PERIOD' ]
        var_name = "_".join(tokens)
        try:
            print("checking %s" % (var_name))
            if var_name in os.environ:
                v = int(os.environ[var_name])
                print("use %s => %d" % (var_name, v))
        except Exception as e:
            pass

        p = p if v is None else v
        return p


    @property
    def data(self):
        self._last_data = self.transform(self.filter(self.measure()))
        return [ self.produce(k, v) for k, v in self._last_data.items() ]
