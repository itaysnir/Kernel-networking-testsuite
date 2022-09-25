#!/usr/bin/python3
import re
import os
import numpy as np

#def reject_outliers(data):
#    d = [abs(data1 - np.average(data)) for data1 in data]
#    mdev = np.average(d)
#    std = np.std(d)
#    s = map(lambda d1 : d1 - mdev if mdev else 0., d)
#    ret = []
#    for i in xrange(len(data)):
#        if abs(s[i]) <= 1.0 * std:
#            ret.append(data[i])
#    return ret
def reject_outliers(data, auto = True, bot = 0, top = -1):
    if auto:
        if len(data) > 8:
            bot = top = 1
        elif len(data) > 4:
            bot = top = 1
        else:
            return data
    if top == -1:
        return data

    return sorted(data)[bot:-top]

def read_iperf(f):
    data = open(f, 'rb').read()
    if data == '':
        return 0.0
    # [  3]  0.0-30.0 sec  57.6 GBytes  16.5 Gbits/sec
    #print f
    #print data
    res = {'iperf' : []}
    r = re.findall(".* (\d+\.\d+) Gbits/sec", data)
    if r == []:
        r = re.findall(".* (\d+) Mbits/sec", data)
        if r == []:
            r = re.findall(".* (\d+\.\d+) Mbits/sec", data)
            if r == []:
                r = re.findall(".* (\d+\.\d+) Kbits/sec", data)
                if r == []:
                    r = re.findall(".* (\d+) Kbits/sec", data)
                    if r == []:
                        r = re.findall(".* (\d+.\d+) bits/sec", data)
                        if r == []:
                            res['iperf'].append(0.0)
                            return res
                r = map(lambda x : float(x) * 10**-3, r)
        r = map(lambda x : float(x) * 10**-3, r)
    res['iperf'] = map(lambda x : float(x), r)
    res['iperf'] = reject_outliers(res['iperf'])
    out = {}
    out['iperf'] = np.average(res['iperf'])
    out['iperf_std'] = np.std(res['iperf'])
    return out

#def read_iperf_times(f):
#    data = open(f, 'rb').read()
#    # [  3]  0.0-30.0 sec  57.6 GBytes  16.5 Gbits/sec
#    r = re.findall("-(\d+\.\d+) sec", data)
#    if len(r)>1 : r=r[:-1]
#    return [float(t) for t in r]

#def read_tls_util(f):
#    data = open(f, 'rb').readlines()
#    data = [float(d.split()[-1]) for d in data if 'rx' in d]
#    if data[1] == 0 and data[0] == 0:
#        return 0
#    #r = (data[0]/(data[0]+data[1]))*100
#    r = (data[1]/(data[0]+data[1]))*100
#    #print r
#    return r

#def read_tls_metadata_util(f):
#    data = open(f, 'rb').readlines()
#    data = [float(d.split()[-1]) for d in data]
#    r = data[1] * 8 * (10 ** -6)
#    #print r
#    return r

#def read_tls_metadata_util2(f):
#    data = open(f, 'rb').read()
#    #tx_tls_drop_metadata_packets 87634
#    md = re.findall("tx_tls_drop_metadata_bytes (\d+)\n", data)
#    #md = re.findall("tx_tls_drop_metadata_packets (\d+)\n", data)
#    #tx_bytes 49767767432
#    total = re.findall("tx_bytes (\d+)", data)
#    #total = re.findall("tx_packets (\d+)", data)
#    if md == []:
#        return 0
#    #print md, total, float(md[0]) / float(total[0])
#    #return ((float(total[0]) - float(md[0])) - float(md[0])) / (float(total[0]) - float(md[0]))
#    return float(md[0]) / (float(total[0]) - float(md[0]))


#def read_cpu_util(f):
#    data = open(f, 'rb').read().split()
#    r = sum(map(lambda x : float(x), data)) / len(data)
#    #print r
#    return r

#def read_tx_bytes(f):
#    data = open(f, 'rb').read()
#    #tx_bytes 114447880230
#    md = re.findall("tx_bytes (\d+)\n", data)
#    if md == []:
#        return 0
#    #print md, total, float(md[0]) / float(total[0])
#    return float(md[0])

def align_std(x):
    return 0 if (x < 0.0001) else x

def _read_net_cpu(f):
    data = open(f, 'r').read()
    #enp4s0f1_rx_packets: 1179901
    res = {}
    for l in data.split('\n'):
        if ':' not in l:
            continue
        try:
            k, v = l.split(': ')
            if k not in res.keys():
                res[k] = []
            res[k].append(float(v))
        except:
            print("[-] Skipping", l)

    res_median = {}
    res_no_outliers = {}
    for k,v in res.items():
        d = np.array(res[k])
        res_no_outliers[k] = reject_outliers(d)
        try:
            res_median[k] = '%.2f' % float(np.average(res_no_outliers[k]))
            res_median[k+'_std'] = '%.2f' % align_std(float(np.std(res_no_outliers[k])))
        except:
            res_median[k] = '%.2f' % float(res[k])
            res_median[k+'_std'] = '%.2f' % max(max(res[k]), abs(min(res[k])))
        #print
        if len(res[k]) > len(res_no_outliers[k]) + 5:
                #assert False, (k, res_median[k], res_median[k+'_std'], len(res[k]), len(res_no_outliers[k]), res[k])
                print (k, res_median[k], res_median[k+'_std'], len(res[k]), len(res_no_outliers[k]), res[k])

    return res_median

def read_net_cpu(f):
    res = _read_net_cpu(f)
    res['Total_tx_bw'] = res['Total_rx_bw'] = res['Total_tx_bytes'] = res['Total_rx_bytes'] = res['Total_tx_packets'] =  res['Total_rx_packets'] =  0
    for k,v in res.items():
        #print k
        if k.endswith('tx_bw'):
            #print k
            res['Total_tx_bw'] += float(v)
        elif k.endswith('rx_bw'):
            #print k
            res['Total_rx_bw'] += float(v)
        elif k.endswith('tx_bytes'):
            #print k
            res['Total_tx_bytes'] += float(v)
        elif k.endswith('rx_bytes'):
            #print k
            res['Total_rx_bytes'] += float(v)
        elif k.endswith('tx_packets'):
            #print k
            res['Total_tx_packets'] += float(v)
        elif k.endswith('rx_packets'):
            #print k
            res['Total_rx_packets'] += float(v)
    #print res['Total_tx_bw'], res['Total_rx_bw'], res['Total_tx_bytes'], res['Total_rx_bytes'], res['Total_tx_packets'], res['Total_rx_packets']
    return res

'''
 |---------------------------------------||---------------------------------------|
 |--             Socket  0             --||--             Socket  1             --|
 |---------------------------------------||---------------------------------------|
 |--     Memory Channel Monitoring     --||--     Memory Channel Monitoring     --|
 |---------------------------------------||---------------------------------------|
 |-- Mem Ch  0: Reads (MB/s):  2599.10 --||-- Mem Ch  0: Reads (MB/s):   449.15 --|
 |--            Writes(MB/s):   262.32 --||--            Writes(MB/s):    11.88 --|
 |-- Mem Ch  1: Reads (MB/s):  2602.05 --||-- Mem Ch  1: Reads (MB/s):   444.88 --|
 |--            Writes(MB/s):   258.62 --||--            Writes(MB/s):     7.96 --|
 |-- Mem Ch  2: Reads (MB/s):  2600.20 --||-- Mem Ch  2: Reads (MB/s):   448.79 --|
 |--            Writes(MB/s):   262.60 --||--            Writes(MB/s):    11.87 --|
 |-- Mem Ch  3: Reads (MB/s):  2598.12 --||-- Mem Ch  3: Reads (MB/s):   444.91 --|
 |--            Writes(MB/s):   258.53 --||--            Writes(MB/s):     7.96 --|
 |-- NODE 0 Mem Read (MB/s) : 10399.46 --||-- NODE 1 Mem Read (MB/s) :  1787.73 --|
 |-- NODE 0 Mem Write(MB/s) :  1042.07 --||-- NODE 1 Mem Write(MB/s) :    39.66 --|
 |-- NODE 0 P. Write (T/s): 4802627619 --||-- NODE 1 P. Write (T/s): 4802550306 --|
 |-- NODE 0 Memory (MB/s):    11441.53 --||-- NODE 1 Memory (MB/s):     1827.39 --|
 |---------------------------------------||---------------------------------------|
 |---------------------------------------||---------------------------------------|
 |--                 System Read Throughput(MB/s):      12187.19                --|
 |--                System Write Throughput(MB/s):       1081.73                --|
 |--               System Memory Throughput(MB/s):      13268.92                --|
 |---------------------------------------||---------------------------------------|

'''
def read_memory(f):
    data = open(f, 'rb').read()
    res = {}
    in_channel = -1
    #print f
    for l in data.split('\n'):
        #print l

        # parse Mem Ch Writes
        if in_channel >= 0:
            r = re.findall("\s+Writes\(MB/s\):\s+(\d+\.\d+)", l)
            #print l
            if r == []:
                continue
            if len(r) >= 2:
                res['socket_0_Ch_%d_Wr' % in_channel].append(r[0])
                res['socket_1_Ch_%d_Wr' % in_channel].append(r[1])
            else:
                pass
            in_channel = -1
            continue

        r = re.findall("Mem Ch  (\d): Reads \(MB/s\):\s+(\d+\.\d+)", l)
        if r != []:
            in_channel = int(r[0][0])
            if not ('socket_0_Ch_%d_Rd' % in_channel) in res.keys():
                res['socket_0_Ch_%d_Rd' % in_channel] = []
                res['socket_1_Ch_%d_Rd' % in_channel] = []
                res['socket_0_Ch_%d_Wr' % in_channel] = []
                res['socket_1_Ch_%d_Wr' % in_channel] = []
            try:
                res['socket_0_Ch_%d_Rd' % in_channel].append(r[0][1])
                res['socket_1_Ch_%d_Rd' % in_channel].append(r[1][1])
            except:
                break
            continue

        r = re.findall("NODE (\d) Mem Read \(MB/s\) :\s+(\d+\.\d+)", l)
        if r != []:
            if not 'node_0_Mem_Read' in res.keys():
                res['node_0_Mem_Read'] = []
                res['node_1_Mem_Read'] = []

            res['node_0_Mem_Read'].append(r[0][1])
            res['node_1_Mem_Read'].append(r[1][1])
            continue

        r = re.findall("NODE (\d) Mem Write\(MB/s\) :\s+(\d+\.\d+)", l)
        if r != []:
            if not 'node_0_Mem_Write' in res.keys():
                res['node_0_Mem_Write'] = []
                res['node_1_Mem_Write'] = []

            res['node_0_Mem_Write'].append(r[0][1])
            res['node_1_Mem_Write'].append(r[1][1])
            continue

        #|-- NODE 0 memory (MB/s):    11441.53 --||-- NODE 1 Memory (MB/s):     1827.39 --|
        r = re.findall("NODE (\d) Memory \(MB/s\):\s+(\d+\.\d+)", l)
        if r != []:
            if not 'node_0_Memory' in res.keys():
                res['node_0_Memory'] = []
                res['node_1_Memory'] = []

            res['node_0_Memory'].append(r[0][1])
            res['node_1_Memory'].append(r[1][1])
            continue

        #|--                 System Read Throughput(MB/s):      12187.19                --|
        r = re.findall("System Read Throughput\(MB/s\):\s+(\d+\.\d+)", l)
        if r != []:
            if not 'sys_Read' in res.keys():
                res['sys_Read'] = []
            res['sys_Read'].append(r[0])
            continue
        #|--                System Write Throughput(MB/s):       1081.73                --|
        r = re.findall("System Write Throughput\(MB/s\):\s+(\d+\.\d+)", l)
        if r != []:
            if not 'sys_Write' in res.keys():
                res['sys_Write'] = []
            res['sys_Write'].append(r[0])
            continue
        #|--               System Memory Throughput(MB/s):      13268.92                --|
        r = re.findall("System Memory Throughput\(MB/s\):\s+(\d+\.\d+)", l)
        if r != []:
            if not 'sys_Memory' in res.keys():
                res['sys_Memory'] = []
            res['sys_Memory'].append(r[0])
            continue

    for k,v in res.items():
        #assert filter(lambda x: float(x) > 100 * 1000, v) == [], "dict[%s] = %s MB/s" % (k,v)
        if filter(lambda x: float(x) > 100 * 1000, v) == []:
            res[k] = filter(lambda x: float(x) < 100 * 1000, v)

    res_out = {}
    #print '!!!! Samples: !!!!!', len(res['sys_Memory'])
    for k,v in res.items():
        #res_out[k] = sum(map(lambda x: float(x), v)) / len(v) / 1000.0
        res_out[k] = '%.2f' % (np.average(map(lambda x: float(x), v)) / 1000.0)

    return res_out

'''
Skt | PCIeRdCur |  RFO  |  CRd  |  DRd  |  ItoM  |  PRd  |  WiL  | PCIe Rd (B) | PCIe Wr (B)
 0    8316           0      43 K   207 K    612       0      36            16 M          39 K   (Total)
 0    8100          24      84      74 K      0       0     108          5323 K        1536     (Miss)
 0     216           0      43 K   132 K    612       0       0            11 M          39 K   (Hit)
 1       0           0    8436    2291 K      0       0       0           147 M           0     (Total)
 1       0           0    1092     113 K      0     372       0          7332 K           0     (Miss)
 1       0           0    7344    2178 K      0       0       0           139 M           0     (Hit)
----------------------------------------------------------------------------------------------------
 *    8316           0      51 K  2499 K    612       0      36           163 M          39 K   (Aggregate)
'''
def read_pcie(f):
    data = open(f, 'rb').read()
    data = data.replace (' G', '000000000')
    data = data.replace (' M', '000000')
    data = data.replace (' K', '000')
    res = {}
    #print f
    for l in data.split('\n'):
        # socket 0 miss
        r = re.findall("0\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)\s+\(Miss\)", l)
        if r != []:
            if not 'sys_pcie_0_miss_rdb' in res.keys():
                res['sys_pcie_0_miss_rdb'] = []
            res['sys_pcie_0_miss_rdb'].append(r[0][0])
            if not 'sys_pcie_0_miss_wrb' in res.keys():
                res['sys_pcie_0_miss_wrb'] = []
            res['sys_pcie_0_miss_wrb'].append(r[0][1])
            continue
        # socket 0 hit
        r = re.findall("0\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)\s+\(Hit\)", l)
        if r != []:
            if not 'sys_pcie_0_hit_rdb' in res.keys():
                res['sys_pcie_0_hit_rdb'] = []
            res['sys_pcie_0_hit_rdb'].append(r[0][0])
            if not 'sys_pcie_0_hit_wrb' in res.keys():
                res['sys_pcie_0_hit_wrb'] = []
            res['sys_pcie_0_hit_wrb'].append(r[0][1])
            continue
        # Aggregate
        r = re.findall("\*\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)\s+\(Aggregate\)", l)
        if r != []:
            if not 'sys_pcie_agg_rdb' in res.keys():
                res['sys_pcie_agg_rdb'] = []
            res['sys_pcie_agg_rdb'].append(r[0][0])
            if not 'sys_pcie_agg_wrb' in res.keys():
                res['sys_pcie_agg_wrb'] = []
            res['sys_pcie_agg_wrb'].append(r[0][1])
            continue

    res_out = {}
    for k,v in res.items():
        #res_out[k] = sum(map(lambda x: float(x), v)) / len(v) / 1000.0
        res_out[k] = '%d' % (np.average(map(lambda x: float(x), v)))

    if 'sys_pcie_0_hit_rdb' in res.keys() and 'sys_pcie_0_hit_wrb' in res.keys():
        res_out['sys_pcie_0_hit_mem'] = '%d' % (float(res_out['sys_pcie_0_hit_wrb']) + float(res_out['sys_pcie_0_hit_rdb']))
    if 'sys_pcie_0_miss_rdb' in res.keys() and 'sys_pcie_0_miss_wrb' in res.keys():
        res_out['sys_pcie_0_miss_mem'] = '%d' % (float(res_out['sys_pcie_0_miss_wrb']) + float(res_out['sys_pcie_0_miss_rdb']))

    #print '!!!! Samples: !!!!!', res_out
    return res_out


def read_fio(f):
    print(f)
    data = open(f, 'rb').read()
    lines = data.split('\n')[:-1]
    res = {
        'rd_bw' : [],
        'wr_bw' : [],
        'rd_bw_std' : [],
        'wr_bw_std' : [],
        'rd_iops' : [],
        'wr_iops' : [],
        'rd_runtime' : [],
        'wr_runtime' : [],
        'rd_avg_lat' : [],
        'wr_avg_lat' : [],
        'rd_std_lat' : [],
        'wr_std_lat' : [],
        'rd_p95_lat' : [],
        'wr_p95_lat' : [],
        }
    for l in lines:
        if l == '' or l.find('fio: terminating') != -1:
            continue
        vals = l.split(';')
        if vals[1].find('fio') == -1:
            fio_ver = 2
            if vals[0] != '2':
                continue
            ver_offset = -1
        else:
            fio_ver = 3
            assert vals[0] == '3', 'bad fio version %s ' %  f
            ver_offset = 0

        name = vals[3 - 1 + ver_offset]
        #print name
        res['op'], res['iodepth'], res['numjobs'], res['blocksize'], res['zerocopy'], res['zerocrc'] = name.split('-')
        res['rd_bw'].append(int(vals[7 - 1 + ver_offset])) # KB/s
        res['rd_bw_std'].append(float(vals[46 - 1 + ver_offset])) # KB/s
        res['rd_iops'].append(int(vals[8 - 1 + ver_offset]))
        res['rd_runtime'].append(int(vals[9 - 1 + ver_offset])) # ms
        res['rd_avg_lat'].append(float(vals[16 - 1 + ver_offset])) # us
        res['rd_std_lat'].append(float(vals[17 - 1 + ver_offset]))
        rd_p95 = vals[29 - 1 + ver_offset]
        assert '95' in rd_p95, 'read p95 latency index is wrong!'
        rd_p95 = rd_p95.split('=')[1]
        res['rd_p95_lat'].append(float(rd_p95)) # us
        res['wr_bw'].append(int(vals[48 - 1 + ver_offset])) # KB/s
        res['wr_bw_std'].append(float(vals[87 - 1 + ver_offset])) # KB/s
        res['wr_iops'].append(int(vals[49 - 1 + ver_offset]))
        res['wr_runtime'].append(int(vals[50 - 1 + ver_offset])) # ms
        res['wr_avg_lat'].append(float(vals[57 - 1 + ver_offset])) # us
        res['wr_std_lat'].append(float(vals[58 - 1 + ver_offset]))
        wr_p95 = vals[70 - 1 + ver_offset]
        assert '95' in wr_p95, 'write p95 latency index is wrong!'
        wr_p95 = wr_p95.split('=')[1]
        res['wr_p95_lat'].append( float(wr_p95)) # us
    res['rd_bw']             = str(np.average(res['rd_bw']))
    res['wr_bw']             = str(np.average(res['wr_bw']))
    res['rd_bw_std']         = str(np.average(res['rd_bw_std']))
    res['wr_bw_std']         = str(np.average(res['wr_bw_std']))
    res['rd_iops']           = str(np.average(res['rd_iops']))
    res['wr_iops']           = str(np.average(res['wr_iops']))
    res['rd_runtime']        = str(np.average(res['rd_runtime']))
    res['wr_runtime']        = str(np.average(res['wr_runtime']))
    res['rd_avg_lat']        = str(np.average(res['rd_avg_lat']))
    res['wr_avg_lat']        = str(np.average(res['wr_avg_lat']))
    res['rd_std_lat']        = str(np.average(res['rd_std_lat']))
    res['wr_std_lat']        = str(np.average(res['wr_std_lat']))
    res['rd_p95_lat']        = str(np.average(res['rd_p95_lat']))
    res['wr_p95_lat']        = str(np.average(res['wr_p95_lat']))
    return res

def dict_append_or_create(d, k, v):
    if not k in d:
        d[k] = [v]
    else:
        d[k].append(v)

def read_perf_stat(f):
    #10043.27,msec,task-clock,10043270741,100.00,0.668,CPUs utilized
    #176024046091,,cycles,90917549301,100.00,,
    #175630864683,,instructions,90917547680,100.00,1.00,insn per cycle
    #19604465,,cache-misses,90917544918,100.00,,
    res = {}
    data = open(f, 'r').read()
    lines = data.split('\n')
    for l in lines:
        if l.startswith('#') or len(l) < 5:
            continue
        #print l, len(l.split(','))
        val,_,name,_,_,_,_ = l.split(',')
        #res['perf_' + name] = val
        try:
            dict_append_or_create(res, 'perf_' + name, int(val))
        except:
            dict_append_or_create(res, 'perf_' + name, float(val))

    for k in list(res):
        #print k, res[k]
        if res[k] != []:
            no_outliers = reject_outliers(res[k])
            if len(no_outliers) > len(res[k]) + 5:
                print (res[k], no_outliers)
            res[k + '_std'] = np.std(no_outliers)
            res[k]          = np.average(no_outliers)
        else:
            res[k + '_std'] = 0
            res[k]          = 0

    return res


def read_dmesg_nvme_trace(f):
    #  nvme_tcp: copy    0          1375526        201638506      40535788772
    #  4 18446744073709551612
    res = {}
    data = open(f, 'rb').read()
    lines = data.split('\n')
    for l in lines:
        # copy
        items = re.findall('.* nvme_tcp: copy\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
                   l)
        if len(items) != 0:
            # TODO: don't assume it is 20 seconds
            if not 'copy_cycles_%d' % int(items[0][0]) in res.keys():
                res['copy_cycles_%d' % int(items[0][0])] = []
            #print 'adding copy %d = %d' % (int(items[0][0]), int(items[0][2]))
            res['copy_cycles_%d' % int(items[0][0])].append(int(items[0][2]) / 20.0)

        # crc
        items = re.findall('.* nvme_tcp: crc\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
                   l)
        if len(items) != 0:
            # TODO: don't assume it is 20 seconds
            if not 'crc_cycles_%d' % int(items[0][0]) in res.keys():
                res['crc_cycles_%d' % int(items[0][0])] = []
            res['crc_cycles_%d' % int(items[0][0])].append(int(items[0][2]) / 20.0)
            #print 'adding crc %d = %d' % (int(items[0][0]), int(items[0][2]))

        # tx_crc
        items = re.findall('.* nvme_tcp: tx_crc\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
                   l)
        if len(items) != 0:
            # TODO: don't assume it is 20 seconds
            if not 'tx_crc_cycles_%d' % int(items[0][0]) in res.keys():
                res['tx_crc_cycles_%d' % int(items[0][0])] = []
            res['tx_crc_cycles_%d' % int(items[0][0])].append(int(items[0][2]) / 20.0)
            #print 'adding tx_crc %d = %d' % (int(items[0][0]), int(items[0][2]))

    for k in res.keys():
        if res[k] != []:
            no_outliers = reject_outliers(res[k])
            if len(no_outliers) > len(res[k]) + 5:
                print (res[k], no_outliers)
            res[k+'_std'] = np.std(no_outliers)
            res[k] = np.average(no_outliers)
        else:
            res[k+'_std'] = 0
            res[k] = 0

    return res

# Thread Stats   Avg      Stdev     Max   +/- Stdev
#     Latency    42.86ms  103.88ms   1.99s    98.04%
#         Req/Sec   206.18     77.13     1.12k    72.89%
#           72410 requests in 30.08s, 38.10GB read
#             Socket errors: connect 0, read 0, write 0, timeout 59
#             Requests/sec:   2407.10
#             Transfer/sec:      1.27GB
def read_wrk(f):
    print(f)
    data = open(f, 'rb').read()
    rate = re.findall("Transfer/sec:\s+(\d+\.\d+)GB", data)
    if len(rate) == 0:
        rate = re.findall("Transfer/sec:\s+(\d+\.\d+)MB", data)
        rate = np.average(map(lambda x : float(x) * 0.001, rate))
    else:
        rate = np.average(map(lambda x : float(x), rate))

    tpsl = re.findall("Requests/sec:\s+(\d+\.\d+)k", data)
    if len(tpsl) != 0:
        tpsl = map(lambda x: float(x)*1000, tpsl)
    else:
        tpsl = re.findall("Requests/sec:\s+(\d+\.\d+)", data)
    tpsl = map(lambda x : float(x), tpsl)
    tpsl_no_outliers = reject_outliers(tpsl)
    if len(tpsl) > len(tpsl_no_outliers):
        print('outliers', len(tpsl), len(tpsl_no_outliers), tpsl)
    tps  = np.average(tpsl_no_outliers)
    tps_std  = np.std(tpsl_no_outliers)
    #print 'tps:', tps

    avg_latency = re.findall("Latency\s+(\d+\.\d+)us\s+\d+\.\d+[mu]?s\s+\d+\.\d+[mu]?s\s+\d+\.\d+\%", data)
    avg_latency = map(lambda x : float(x), avg_latency)
    if len(avg_latency) == 0:
        avg_latency = re.findall("Latency\s+(\d+\.\d+)ms\s+\d+\.\d+[mu]?s\s+\d+\.\d+[mu]?s\s+\d+\.\d+\%", data)
        avg_latency = map(lambda x : float(x) * 1000, avg_latency)
    #print 'avg_latency', avg_latency
    #assert False, 'latency %s %s' % (f, avg_latency)

    std_latency = re.findall("Latency\s+\d+\.\d+[mu]?s\s+(\d+\.\d+)us\s+\d+\.\d+[mu]?s\s+\d+\.\d+\%", data)
    std_latency = map(lambda x : float(x), std_latency)
    if len(std_latency) == 0:
        std_latency = re.findall("Latency\s+\d+\.\d+[mu]?s\s+(\d+\.\d+)ms\s+\d+\.\d+[mu]?s\s+\d+\.\d+\%", data)
        std_latency = map(lambda x : float(x) * 1000, std_latency)

    avg_lat_res_out = reject_outliers(avg_latency)
    avg_latency_res = np.average(avg_lat_res_out)
    avg_std_latency_res = np.std(avg_lat_res_out)
    std_lat_res_out = reject_outliers(std_latency)
    std_latency_res = np.std(std_lat_res_out)
    print(avg_std_latency_res, avg_lat_res_out)
    #assert False, 'latency %s %s %s' % (f, avg_latency_res, std_latency_res)
    #print f, rate, tps, avg_latency

    #latency_50 = float(re.findall("50% latency:          (\d+\.\d+) milliseconds",data)[0])
    #latency_90 = float(re.findall("90% latency:          (\d+\.\d+) milliseconds",data)[0])
    res = {}
    res['wrk_bw'] = rate * 8
    res['wrk_tps'] = tps
    res['wrk_tps_std'] = tps_std
    res['wrk_lat_avg'] = avg_latency_res
    res['wrk_lat_std'] = std_latency_res
    res['wrk_lat_avg_std'] = avg_std_latency_res
    #print '!!!!!',f, res['wrk_tps']
    return res

#===============================================
#Type         Ops/sec      Latency       KB/sec
#-----------------------------------------------
#Gets         3238.93      1.23300    207398.81
#Totals       3238.93      1.23300    207398.81
def read_memt_out(f):
    print(f)
    a = open(f, 'rb').read()
    df = a.split('*********************************##################################')
    res = []
    for data in df:
        if data.find('Gets') == -1:
            continue
        gps = re.findall("Gets\s+(\d+\.\d+).", data)
        assert len(gps) != 0, gps
        lat = re.findall("Gets\s+\d+\.\d+\s+(\d+\.\d+).*", data)
        assert len(lat) != 0, lat
        res.append({'memt_gets' : sum(map(lambda x : float(x), gps)),
                'memt_lats' : np.average(map(lambda x : float(x), lat))})
    #print '!!!!!!!!!' + str(res)
    if len(res) >= 7:
        res = sorted(res, key = lambda x : x['memt_gets'])[1:-1]
    #res = reject_outliers(d)

    d = {'memt_gets' : np.average(map(lambda x : x['memt_gets'], res)),
         'memt_lats' : np.average(map(lambda x : x['memt_lats'], res)),
         'memt_gets_std' : np.std(map(lambda x : x['memt_gets'], res)),
         'memt_lats_std' : np.std(map(lambda x : x['memt_lats'], res))
         }
    #print d
    return d

def read_dmesg_tls_trace(f):
#     [109986.472201] cpu_profile: calibration  average is 24 clock cycles, min is 24, max is 24
#     [110011.929185] tls trace              enc              dec
#     [110011.935218] tls trace      21155027336                0
    res = {}
    data = open(f, 'rb').read()
    lines = data.split('\n')
    for l in lines:
        # copy
        items = re.findall('.*tls trace\s+(\d+)\s+(\d+)', l)
        if len(items) != 0:
            # TODO: don't assume it is 20 seconds
            if not 'enc_cycles' in res.keys():
                res['enc_cycles'] = []
            if not 'dec_cycles' in res.keys():
                res['dec_cycles'] = []
            #print 'adding enc %d cycles dec %d cycles' % (int(items[0][0]) / 20.0, int(items[0][1]) / 20.0)
            # TODO: get the runtime somehow
            res['enc_cycles'].append(int(items[0][0]) / 20.0)
            res['dec_cycles'].append(int(items[0][1]) / 20.0)

    res['enc_cycles'] = reject_outliers(res['enc_cycles'])
    res['dec_cycles'] = reject_outliers(res['dec_cycles'])
    out = {}
    for k in res.keys():
        if res[k] != []:
            out[k] = np.average(res[k])
            out[k+'_std'] = np.std(res[k])
            print('tls cycles', out, res)
        else:
            out[k] = 0

    return out

def read_tls_decrypted(f):
    res = {'tls_enc' : [], 'tls_enc_full' : [], 'tls_dec' : []}
    data = open(f, 'rb').read()
    lines = data.split('\n')
    for l in lines:
        if len(l) < 3:
            continue
        name, val = l.split(':')
        val = float(val)
        if name == 'enc':
            res['tls_enc'].append(val)
        elif name == 'enc_full':
            res['tls_enc_full'].append(val)
        elif name == 'dec':
            res['tls_dec'].append(val)
        else:
            assert False, l

    ###############
    res_median = {}
    res_no_outliers = {}
    for k in res.keys():
        d = np.array(res[k])
        #print k, res[k]
        res_no_outliers[k] = reject_outliers(d)
        #print k, res_no_outliers[k]
        try:
            res_median[k] = int(np.average(res_no_outliers[k]))
            res_median[k+'_std'] = float(np.std(res_no_outliers[k]))
        except:
            res_median[k] = int(res[k])
            res_median[k+'_std'] = max(max(res[k]), abs(min(res[k])))
        #print
        if len(res[k]) > len(res_no_outliers[k]) + 4:
            assert False, (k, res_median[k], res_median[k+'_std'], len(res[k]), len(res_no_outliers[k]), res[k])
        #print k, res_median[k]

    return res_median

def is_ascii(s):
    not_low = filter(lambda c : not (97 <= ord(c) <= 122), s)
    not_high = filter(lambda c : not (65 <= ord(c) <= 90), not_low)
    not_num = filter(lambda c : not (48 <= ord(c) <= 57), not_high)
    not_sign = filter(lambda c : not (ord(c) in [ord('-'), ord('_'), ord('+')]), not_num)
    #print 'not_sign', type(not_sign), not_sign
    return not_sign == ""

def read_env(f):
    res = {}
    data = open(f, 'rb').read()
    lines = data.split('\n')
    for l in lines:
        try:
            name, val = l.split('=')
        except:
            continue
        if name == '' or val == '' or not is_ascii(name) or not is_ascii(val):
            continue
        #print 'env name', name
        #print 'env val', val
        res[name] = val
    return res

'''
tx_cyc=24713349976
rx_cyc=26102800856
lookup_cyc=32128821656
idle_cyc=195448781
'''
def read_l3fwd(f):
    res = {}
    data = open(f, 'rb').read()
    lines = data.split('\n')
    for l in lines:
        # tx_cyc
        items = re.findall('\s+tx_cyc=(\d+)', l)
        if len(items) != 0:
            if not 'l3fwd_tx_cyc' in res.keys():
                res['l3fwd_tx_cyc'] = []
            res['l3fwd_tx_cyc'].append(int(items[0]))
        # rx_cyc
        items = re.findall('\s+rx_cyc=(\d+)', l)
        if len(items) != 0:
            if not 'l3fwd_rx_cyc' in res.keys():
                res['l3fwd_rx_cyc'] = []
            res['l3fwd_rx_cyc'].append(int(items[0]))
        # lookup_cyc
        items = re.findall('\s+lookup_cyc=(\d+)', l)
        if len(items) != 0:
            if not 'l3fwd_lookup_cyc' in res.keys():
                res['l3fwd_lookup_cyc'] = []
            res['l3fwd_lookup_cyc'].append(int(items[0]))
        # idle_cyc
        items = re.findall('\s+idle_cyc=(\d+)', l)
        if len(items) != 0:
            if not 'l3fwd_idle_cyc' in res.keys():
                res['l3fwd_idle_cyc'] = []
            res['l3fwd_idle_cyc'].append(int(items[0]))
        # total_cyc
        items = re.findall('\s+total_cyc=(\d+)', l)
        if len(items) != 0:
            if not 'l3fwd_total_cyc' in res.keys():
                res['l3fwd_total_cyc'] = []
            res['l3fwd_total_cyc'].append(int(items[0]))

    res['l3fwd_rx_cyc'] = reject_outliers(res['l3fwd_rx_cyc'])
    res['l3fwd_tx_cyc'] = reject_outliers(res['l3fwd_tx_cyc'])
    res['l3fwd_lookup_cyc'] = reject_outliers(res['l3fwd_lookup_cyc'])
    res['l3fwd_idle_cyc'] = reject_outliers(res['l3fwd_idle_cyc'])
    res['l3fwd_total_cyc'] = reject_outliers(res['l3fwd_total_cyc'])
    out = {}
    for k in res.keys():
        if res[k] != []:
            out[k] = np.average(res[k])
            out[k+'_std'] = np.std(res[k])
            print('l3fwd cycles', out, res)
        else:
            out[k] = 0

    return out
