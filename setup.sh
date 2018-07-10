#!/bin/bash -xe
sudo su -c :

SSH="ssh -o LogLevel=quiet -o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -p 2222 -i id_rsa ubuntu@localhost"

function wait_until_ssh_ready() {
    while ! ${SSH} -o ConnectTimeout=3 "exit 0"; do sleep 1; done
}

function kill_qemu() {
    sudo pkill qemu-system-x86 || :
}

if [ ! -e ubuntu-16.04-server-cloudimg-amd64-disk1.qcow2 ]; then
    if [ ! -e ubuntu-16.04-server-cloudimg-amd64-disk1.img ]; then
	wget https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
    fi
    qemu-img convert -O qcow2 ubuntu-16.04-server-cloudimg-amd64-disk1.img ubuntu-16.04-server-cloudimg-amd64-disk1.qcow2
fi
cp ubuntu-16.04-server-cloudimg-amd64-disk1.qcow2 work/
cd work

qemu-img create -f qcow2 -b ubuntu-16.04-server-cloudimg-amd64-disk1.qcow2 ubuntu-16.04-server-cloudimg-amd64-disk1.diff.qcow2

kill_qemu
cloud-localds -d qcow2 cloud.qcow2 ../cloud-config.yml

trap 'kill_qemu;' SIGINT ERR

sudo qemu-system-x86_64 -cpu Haswell -nographic -hda ubuntu-16.04-server-cloudimg-amd64-disk1.diff.qcow2 -hdb cloud.qcow2 -smp 5 -m 4G -net nic -net user,hostfwd=tcp::2222-:22 -enable-kvm > /dev/null 2>&1 &
wait_until_ssh_ready
${SSH} "bash -s" < ../install_script
${SSH} "sudo poweroff" || :

while pgrep qemu-system-x86; do sleep 1; done

qemu-system-x86_64 -cpu Haswell -nographic -hda ubuntu-16.04-server-cloudimg-amd64-disk1.diff.qcow2 -hdb cloud.qcow2 -smp 5 -m 4G -net nic -net user,hostfwd=tcp::2222-:22 -serial telnet:127.0.0.1:4444,server,nowait -monitor telnet:127.0.0.1:4445,server,nowait > /dev/null 2>&1 &
sleep 5
expect -c "
set timeout -1
spawn telnet localhost 4444
expect \"ubuntu login:\"
"
while [ $(ps aux | grep qemu-system-x86 | grep -v grep | awk {'print $3*100'}) -gt 2500 ]; do sleep 1; done
${SSH} "ps aux"
sleep 3
echo "stop" | netcat localhost 4445
echo "savevm snapshot1" | netcat localhost 4445
echo "quit" | netcat localhost 4445

trap SIGINT ERR

rm ubuntu-16.04-server-cloudimg-amd64-disk1.qcow2
tar jcvf ../hakase_qemuimage_$(openssl rand -base64 24).tar.bz2 .

echo "setup done!"
