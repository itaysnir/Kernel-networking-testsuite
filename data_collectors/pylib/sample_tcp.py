#!/usr/bin/python
from subprocess import Popen, PIPE
from sys import argv, exit
from time import sleep
import re

#Tcp: RtoAlgorithm RtoMin RtoMax MaxConn ActiveOpens PassiveOpens AttemptFails EstabResets CurrEstab InSegs OutSegs RetransSegs InErrs OutRsts InCsumErrors
#Tcp: 1 200 120000 -1 2197 10 1 16 2 299274253 270486626 0 0 272 0
def comp_tcp():
    output = Popen("cat /proc/net/snmp", shell = True, stdout = PIPE).stdout.read()
    t = re.findall('Tcp: (\d+) (\d+) (\d+) ([-]\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)', output)[0]
    #print t
    out = {'InSegs' : t[9],'OutSegs' : t[10]}
    return out

def main():
    sstat = comp_tcp()
    t = int(argv[1])
    sleep(t)
    estat = comp_tcp()
    for k in sstat.keys():
        print k + ': ' + str(int(estat[k]) - int(sstat[k]))

if __name__ == '__main__':
    if len(argv) != 2:
        exit('Usage: %s <sleep-time>' % argv[0])
    main()


