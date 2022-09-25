#!/usr/bin/python3
from sys import argv,exit
from os.path import isdir, basename, dirname
from glob import glob
from perf_util import read_net_cpu, read_memory, read_fio, read_perf_stat,\
                      read_dmesg_nvme_trace, read_wrk, read_memt_out,\
                      read_dmesg_tls_trace, read_iperf, read_tls_decrypted

def hash2csv(name, res):
    cols = []
    # join all keys in a single list of unique keys
    [cols.extend(res[t].keys()) for t in res.keys()]
    cols = list(set(cols))
    print ('[+] Columns:', cols)
    l = 'name,test,'
    for k in cols:
        l += k + ','
    csv = l+'\n'
    for test in res.keys():
        l = '%s,%s,' % (name, test)
        for c in cols:
            try:
                l += '%s,' % res[test][c]
            except:
                l += '0,'
        csv += l+'\n'
    return csv

parsers = {
'eth.txt' : read_net_cpu,
'cpu.txt' : read_net_cpu,
'memory.txt' : read_memory,
'fio.terse' : read_fio,
'perf_stat.txt' : read_perf_stat,
'dmesg_nvme_trace.txt' : read_dmesg_nvme_trace,
'dmesg_tls_trace.txt' : read_dmesg_tls_trace,
'nginx.txt' : read_wrk,
'memt.out' : read_memt_out,
'iperf.txt' : read_iperf,
'tls_decrypt.txt' : read_tls_decrypted,
}

def parse(d):
    res = {}
    files = glob(d + '/*')
    #print 'files', files
    for f in files:
        #fname = f.split('/')[-1]
        fname = basename(f)
        if not f.endswith('.txt') and not f.endswith('.terse') and not f.endswith('.out'):
            print('[-] Skipping parsing non-txt/terse/out file %s' % fname)
            continue

        if fname not in parsers.keys():
            print('[-] Skipping parsing unknown file %s' % fname)
            continue
        print('[+] Parsing file %s' % fname)
        res.update(parsers[fname](f))
    return res

def parse_base(d):
    dirs = glob(d + '/*')
    res = {}
    for name in dirs:
        dname = basename(name)
        if not isdir(name):
            print('[-] Skipping non-directory in base: %s' % dname)
            continue
        print('[+] Parsing directory %s' % dname)
        res[dname] = parse(name)
    return res

if __name__ == '__main__':
    # argv[1] is a directory containing subdirectories with test results
    if len(argv) < 2:
        print('Usage: %s <base-directory>' % argv[0])
        exit(1)
    d = argv[1]
    res = parse_base(d)
    csv = hash2csv(basename(d), res)
    open(d + '/setup.csv', 'w').write(csv)
    print('[+] Saved CSV in %s' % (d + '/setup.csv'))
