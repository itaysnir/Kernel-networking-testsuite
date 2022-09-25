#!/bin/bash
awk -F\' '$1=="menuentry " {print i++ " : " $2}' /boot/grub/grub.cfg
awk -F\' '/menuentry / {print i++ " : " $2}' /boot/grub/grub.cfg 

