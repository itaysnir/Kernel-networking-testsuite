#!/bin/bash

[ -z "$1" ] && echo 'Usage: <filename>' && exit;

for f in `ls /sys/block/$1/queue`; do
    echo /sys/block/$1/queue/$f `cat /sys/block/$1/queue/$f`
done

for f in `ls /sys/block/$1/queue/iosched`; do
    echo /sys/block/$1/queue/iosched/$f `cat /sys/block/$1/queue/iosched/$f`
done
