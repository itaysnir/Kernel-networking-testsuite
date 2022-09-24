#!/usr/bin/python
import sys
import time

def calc_cpu(f):
    res = []
    for line in f.split('\n'):
        if not line.startswith('cpu'):
            continue
        l = line.split()
        user = int(l[1])
        nice = int(l[2])
        system = int(l[3])
        idle = int(l[4])
        iowait = int(l[5])
        irq = int(l[6])
        softirq = int(l[7])
        try:
            steal = int(l[8])
            guest = int(l[9])
            guest_nice = int(l[10])
        except:
            steal = guest = guest_nice = 0

        busy = user + nice + system + irq + softirq + steal + guest + guest_nice
        idle = idle + iowait
        #idle = idle
        total = busy + idle
        res.append((busy, idle))
    return res


f = open("/proc/stat")
start = f.read()
#print int(sys.argv[1])
t = int(sys.argv[1])
time.sleep(t)
f.seek(0)
end = f.read()


#print start
#print end

sres = calc_cpu(start)
eres = calc_cpu(end)
diff = [(eb -sb, ei - si) for ((sb, si), (eb, ei)) in zip(sres,eres)]
#print diff

# Only idle is valid:
# proc stat based cpu util, proc/stat misses some ticks so only idle(idx 4) are valid
# int(time * USER_HZ) = expected total ticks ET.
# cpu util = ET - Ticks/ET;
USER_HZ = 100
ET = USER_HZ * t
cpu_utils = []
num_cpus = len(sres) - 1
cpu_utils.append(max(0, 100.0 * (ET * num_cpus - diff[0][1]) / (ET * num_cpus)))
print 'cpu_total: %3.2f' % cpu_utils[0]
for c in xrange(num_cpus):
    cpu_utils.append(max(0, 100 * (ET - diff[1 + c][1]) / ET))
    print 'cpu_%d: %3.2f' % (1 + c, cpu_utils[1 + c])
print 'cpu_total2: %5.2f' % sum(cpu_utils[1:])
