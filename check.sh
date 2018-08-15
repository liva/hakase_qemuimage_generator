#!/bin/sh
cd work
cp ../ubuntu-16.04-server-cloudimg-amd64-disk1.qcow2 .
qemu-system-x86_64 -loadvm snapshot1 -cpu Haswell -curses -hda ubuntu-16.04-server-cloudimg-amd64-disk1.diff.qcow2 -hdb cloud.qcow2 -smp 5 -m 4G -net nic -net user,hostfwd=tcp::2222-:22,hostfwd=tcp::2873-:873 -serial telnet:127.0.0.1:4444,server,nowait -monitor telnet:127.0.0.1:4445,server,nowait
