#!/usr/bin/python
from subprocess import Popen, PIPE
from sys import argv, exit
from time import sleep

def calc_tls():
    enc        = open('/sys/module/tls/parameters/rx_encrypted', 'rb').read()
    enc_full   = open('/sys/module/tls/parameters/rx_encrypted_full', 'rb').read()
    dec        = open('/sys/module/tls/parameters/rx_decrypted', 'rb').read()
    return [
            ('enc'      , int(enc)     ),
            ('enc_full' , int(enc_full)),
            ('dec'      , int(dec)     )
            ]

def main():
    sstat = calc_tls()
    t = int(argv[1])
    sleep(t)
    estat = calc_tls()
    stat_zip = zip(sstat, estat)
    for (t1,n1), (t2,n2) in stat_zip:
        assert t1 == t2, "different text %s vs. %s" % (t1, t2)
        value = abs(n2 - n1) / float(t)
        print "%s: %d" % (t1.lstrip(), value)

if __name__ == '__main__':
    if len(argv) != 2:
        exit('Usage: %s <sleep-time>' % argv[0])
    main()


