#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
import psutil

# Helper classes and functions
#
from base_sensor import BaseSensor
from sensor_util import SensorData


def decouple_nested_list(l):
    return [ y for x in l for y in x ]



class DataTypeTransformSensor(BaseSensor):
    def __init__(self, data_type_aliases=None):
        super().__init__()
        self._data_type_aliases = data_type_aliases if data_type_aliases is not None else {}

    def find_data_type_alias(self, data_type):
        aliases = self._data_type_aliases
        return aliases[data_type] if data_type in aliases else data_type

    def transform(self, props):
        ps = super().transform(props)
        return dict([ (self.find_data_type_alias(k), v) for k, v in props.items() ])



class MainboardSensor(DataTypeTransformSensor):
    def __init__(self):
        super().__init__(data_type_aliases={'percent': 'percentage'})
        self._base.board_type = 'mainboard'
        self._base.board_id = '7F000001'
        self._unit_length_defs['percentage'] = '%'

    def find_data_type_alias(self, data_type):
        aliases = self._data_type_aliases
        return aliases[data_type] if data_type in aliases else data_type

    def transform(self, props):
        ps = super().transform(props)
        return dict([ (self.find_data_type_alias(k), v) for k, v in props.items() ])



class ConstantMainboardSensor(MainboardSensor):
    def __init__(self, sensor, constant_data, exclusive_list=None, unit_length_defs=None):
        super().__init__()
        self._base.sensor = sensor
        self._constant_data = constant_data
        if exclusive_list is not None:
            self._exclusive_list = self._exclusive_list + exclusive_list
        if unit_length_defs is not None:
            self._unit_length_defs.update(unit_length_defs)

    def measure(self):
        return self._constant_data



# >>> psutil.cpu_times()
# scputimes(
#   user=3961.46,
#   nice=169.729,
#   system=2150.659,
#   idle=16900.540,
#   iowait=629.59,
#   irq=0.0,
#   softirq=19.42,
#   steal=0.0,
#   guest=0,
#   nice=0.0)
#
#
# OUTPUT:
#
# mainboard 7F000001 cpu_times nice     0.0
# mainboard 7F000001 cpu_times irq      0.08
# mainboard 7F000001 cpu_times steal    0.0
# mainboard 7F000001 cpu_times system   64.75
# mainboard 7F000001 cpu_times user     416.46
# mainboard 7F000001 cpu_times idle     324748.65
# mainboard 7F000001 cpu_times softirq  12.3
# mainboard 7F000001 cpu_times iowait   8.13
#
class CpuTimesSensor(MainboardSensor):
    def __init__(self):
        super().__init__()
        self._base.sensor = 'cpu_times'
        self._exclusive_list = ['guest', 'guest_nice']
        self._preferred_period = 5

    def measure(self):
        return psutil.cpu_times()._asdict()


# psutil.cpu_percent()
#
class CpuPercentageSensor(MainboardSensor):
    def __init__(self):
        super().__init__()
        self._base.sensor = 'cpu'
        self._preferred_period = 2


    def measure(self):
        p = psutil.cpu_percent()
        return {'percentage': p}


# psutil.cpu_percent(percpu=True)
#
# mainboard 7F000001 cpu0 percentage 0.0
# mainboard 7F000001 cpu1 percentage 0.0
# mainboard 7F000001 cpu2 percentage 0.0
# mainboard 7F000001 cpu3 percentage 0.0
#
class CpuAllPercentagesSensor(MainboardSensor):
    def __init__(self):
        super().__init__()
        self._base.sensor = 'cpu'
        self._preferred_period = 2

    def measure(self):
        percentages = psutil.cpu_percent(percpu=True)
        return dict([ (("cpu%s" % i), p) for i, p in enumerate(percentages) ])

    @property
    def data(self):
        percentages = psutil.cpu_percent(percpu=True)
        b = self._base.duplicate(data_type="percentage")
        return [ b.duplicate(sensor=("cpu%s" % i), value=p) for i, p in enumerate(percentages) ]


STORAGE_UNIT_LENGTH_DEFINITIONS = {
    'total': 'bytes',
    'available': 'bytes',
    'used': 'bytes',
    'free': 'bytes',
    'active': 'bytes',
    'inactive': 'bytes',
    'buffers': 'bytes',
    'cached': 'bytes',
}


class MemorySensor(MainboardSensor):
    def __init__(self):
        super().__init__()
        self._unit_length_defs.update(STORAGE_UNIT_LENGTH_DEFINITIONS)


# >>> psutil.virtual_memory()
# svmem(
#   total=2098601984,
#   available=1901711360,
#   percent=9.4,
#   used=879296512,
#   free=1219305472,
#   active=516730880,
#   inactive=190689280,
#   buffers=130043904,
#   cached=552361984
# )
#
# mainboard 7F000001 virtual_memory used        879239168 bytes
# mainboard 7F000001 virtual_memory buffers     130121728 bytes
# mainboard 7F000001 virtual_memory cached      552382464 bytes
# mainboard 7F000001 virtual_memory inactive    190672896 bytes
# mainboard 7F000001 virtual_memory free        1219362816 bytes
# mainboard 7F000001 virtual_memory available   1901867008 bytes
# mainboard 7F000001 virtual_memory active      516939776 bytes
# mainboard 7F000001 virtual_memory total       2098601984 bytes
# mainboard 7F000001 virtual_memory percentage  9.4 %
#
class VirtualMemorySensor(MemorySensor):
    def __init__(self):
        super().__init__()
        self._base.sensor = 'virtual_memory'
        self._preferred_period = 60

    def measure(self):
        return psutil.virtual_memory()._asdict()



# >>> psutil.swap_memory()
# sswap(
#   total=536866816L,
#   used=0L,
#   free=536866816L,
#   percent=0.0
#   sin=0,
#   sout=0
# )
#
#
# mainboard 7F000001 swap_memory used       0 bytes
# mainboard 7F000001 swap_memory sin        0
# mainboard 7F000001 swap_memory free       536866816 bytes
# mainboard 7F000001 swap_memory sout       0
# mainboard 7F000001 swap_memory total      536866816 bytes
# mainboard 7F000001 swap_memory percentage 0.0 %
#
class SwapMemorySensor(MemorySensor):
    def __init__(self):
        super().__init__()
        self._base.sensor = 'swap_memory'
        self._preferred_period = 60 * 60

    def measure(self):
        return psutil.swap_memory()._asdict()


# psutil.disk_partitions()
#
# [
#   sdiskpart(
#       device='/dev/mapper/vagrant--vg-root',
#       mountpoint='/',
#       fstype='ext4',
#       opts='rw,errors=remount-ro'
#   ),
#
#   sdiskpart(
#       device='/dev/sda1',
#       mountpoint='/boot',
#       fstype='ext2',
#       opts='rw'
#   )
# ]
#
#
# mainboard 7F000001 disk0 device       /dev/mapper/vagrant--vg-root
# mainboard 7F000001 disk0 fstype       ext4
# mainboard 7F000001 disk0 mountpoint   /
# mainboard 7F000001 disk1 device       /dev/sda1
# mainboard 7F000001 disk1 fstype       ext2
# mainboard 7F000001 disk1 mountpoint   /boot
#
class DiskPartitionSensor(MainboardSensor):
    def __init__(self):
        super().__init__()
        self._base.sensor = 'disk'
        self._preferred_period = 60 * 60 * 24

    def measure(self):
        return psutil.disk_partitions()

    @property
    def data(self):
        disks = self.measure()
        data_list = [
            ConstantMainboardSensor(
                sensor=("disk%d" % i),
                constant_data=disk._asdict(),
                exclusive_list=['opts']
            ).data
            for i, disk in enumerate(disks)
        ]
        return decouple_nested_list(data_list)


# [ psutil.disk_usage(disk.mountpoint) for i, disk in enumerate(psutil.disk_partitions()) ]
#
# [
#   sdiskusage(
#       total=66720665600,
#       used=2247462912,
#       free=61060300800,
#       percent=3.4
#   ),
#   sdiskusage(
#       total=246755328,
#       used=38456320,
#       free=195559424,
#       percent=15.6
#   )
# ]
#
#
# mainboard 7F000001 disk0 used         2247467008 bytes
# mainboard 7F000001 disk0 free         61060296704 bytes
# mainboard 7F000001 disk0 total        66720665600 bytes
# mainboard 7F000001 disk0 percentage   3.4 %
# mainboard 7F000001 disk1 used         38456320 bytes
# mainboard 7F000001 disk1 free         195559424 bytes
# mainboard 7F000001 disk1 total        246755328 bytes
# mainboard 7F000001 disk1 percentage   15.6 %
#
class DiskUsageSensor(MainboardSensor):
    def __init__(self):
        super().__init__()
        self._base.sensor = 'disk'
        self._preferred_period = 60

    @property
    def data(self):
        disks = psutil.disk_partitions()
        usages = [ psutil.disk_usage(disk.mountpoint) for i, disk in enumerate(disks) ]
        data_list = [
            ConstantMainboardSensor(
                sensor=("disk%d" % i),
                constant_data=usage._asdict(),
                unit_length_defs=STORAGE_UNIT_LENGTH_DEFINITIONS
            ).data
            for i, usage in enumerate(usages)
        ]
        return decouple_nested_list(data_list)


# >>> psutil.disk_io_counters()
# sdiskio(
#   read_count=68397,
#   write_count=33116,
#   read_bytes=998363136,
#   write_bytes=1001880576,
#   read_time=129460,
#   write_time=252660
# )
#
# OUTPUT:
#
# mainboard 7F000001 diskio read_count      0
# mainboard 7F000001 diskio write_count     0
# mainboard 7F000001 diskio read_bytes      0 bytes
# mainboard 7F000001 diskio write_bytes     0 bytes
# mainboard 7F000001 diskio read_time       0
# mainboard 7F000001 diskio write_time      0
# mainboard 7F000001 diskio accumulated_read_count  68397
# mainboard 7F000001 diskio accumulated_write_count 33210
# mainboard 7F000001 diskio accumulated_write_time  252660
# mainboard 7F000001 diskio accumulated_read_time   129460
# mainboard 7F000001 diskio accumulated_read_bytes  998363136 bytes
# mainboard 7F000001 diskio accumulated_write_bytes 1002363904 bytes
#
class DiskIoSensor(MainboardSensor):
    def __init__(self):
        super().__init__()
        self._last_disk_ios = {}
        self._preferred_period = 60

    def measure(self):
        return psutil.disk_io_counters()._asdict()

    @property
    def data(self):
        disk_ios = self.measure()
        last_disk_ios = self._last_disk_ios
        data_list = [
            ConstantMainboardSensor(
                sensor='diskio',
                constant_data={k: v - last_disk_ios[k] if k in last_disk_ios else 0},
                unit_length_defs={'read_bytes': 'bytes', 'write_bytes': 'bytes'}
            ).data
            for k, v in disk_ios.items()
        ]
        new_disk_ios = { ("accumulated_%s" % k): v for k, v in disk_ios.items() }
        accumuated_data_list = ConstantMainboardSensor(
                sensor='diskio',
                constant_data=new_disk_ios,
                unit_length_defs={'accumulated_read_bytes': 'bytes', 'accumulated_write_bytes': 'bytes'}
        ).data
        return decouple_nested_list(data_list) + accumuated_data_list


# psutil.net_if_addrs()
#
# {
#   'lo': [
#       snic(
#           family=2,
#           address='127.0.0.1',
#           netmask='255.0.0.0',
#           broadcast=None,
#           ptp=None
#       ),
#       snic(
#           family=10,
#           address='::1',
#           netmask='ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
#           broadcast=None,
#           ptp=None
#       ),
#       snic(
#           family=17,
#           address='00:00:00:00:00:00',
#           netmask=None,
#           broadcast=None,
#           ptp=None
#       )
#   ],
#   'docker0': [
#       snic(
#           family=2,
#           address='172.17.42.1',
#           netmask='255.255.0.0',
#           broadcast='172.17.42.1',
#           ptp=None
#       ),
#       snic(
#           family=10,
#           address='fe80::f443:ceff:fef5:cd03%docker0',
#           netmask='ffff:ffff:ffff:ffff::',
#           broadcast=None,
#           ptp=None
#       ),
#       snic(
#           family=17,
#           address='f6:43:ce:f5:cd:03',
#           netmask=None,
#           broadcast='ff:ff:ff:ff:ff:ff',
#           ptp=None
#       )
#   ],
#   'eth0': [
#       snic(
#           family=2,
#           address='10.0.2.15',
#           netmask='255.255.255.0',
#           broadcast='10.0.2.255',
#           ptp=None
#       ),
#       snic(
#           family=10,
#           address='fe80::a00:27ff:fe63:2471%eth0',
#           netmask='ffff:ffff:ffff:ffff::',
#           broadcast=None,
#           ptp=None
#       ),
#       snic(
#           family=17,
#           address='08:00:27:63:24:71',
#           netmask=None,
#           broadcast='ff:ff:ff:ff:ff:ff',
#           ptp=None
#       )
#   ]
# }
#

AllPsSensorClasses = [
    CpuPercentageSensor, CpuAllPercentagesSensor, CpuTimesSensor,
    VirtualMemorySensor, SwapMemorySensor,
    DiskPartitionSensor, DiskUsageSensor, DiskIoSensor
]

