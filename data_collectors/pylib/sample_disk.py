#!/usr/bin/python
from subprocess import Popen, PIPE
from sys import argv, exit
from time import sleep

# see https://www.kernel.org/doc/Documentation/ABI/testing/procfs-diskstats
def comp_diskstats(disk):
    output = Popen("grep %s /proc/diskstats" % disk, shell = True, stdout = PIPE).stdout.read()
    l = output.split()
    print output
    stats = {}
    stats['major']            = int(l[0])
    stats['minor']            = int(l[1])
    stats['name']             = str(l[2])
    stats['reads']            = int(l[3])
    stats['reads_merged']     = int(l[4])
    stats['reads_sectors']    = int(l[5])
    stats['reads_time']       = int(l[6])
    stats['writes']           = int(l[7])
    stats['writes_merged']    = int(l[8])
    stats['writes_sectors']   = int(l[9])
    stats['writes_time']      = int(l[10])
    stats['io_inprogress']    = int(l[11])
    stats['io_time']          = int(l[12])
    _                = int(l[13])
    try:
        stats['discards']         = int(l[14])
        stats['discards_merged']  = int(l[15])
        stats['discards_sectors'] = int(l[16])
        stats['discards_time']    = int(l[17])
    except:
        pass
    try:
        stats['flash']           = int(l[20])
        stats['flash_time']      = int(l[21])
    except:
        pass
    return stats.items()

def bytes2gbps(n):
    return float(n) * 8 / 1000 / 1000 / 1000

def main():
    disk = argv[2]
    sstat = comp_diskstats(disk)
    t = int(argv[1])
    sleep(t)
    estat = comp_diskstats(disk)
    stat_zip = zip(sstat, estat)
    for (t1,n1), (t2,n2) in stat_zip:
        assert t1 == t2, "different text %s vs. %s" % (t1, t2)
        if n1 != n2:
            value = abs(n2 - n1) / float(t)
            print "%s_%s: %d" % (disk, t1.lstrip(), value)

if __name__ == '__main__':
    if len(argv) != 3:
        exit('Usage: %s <sleep-time> <disk>' % argv[0])
    main()


