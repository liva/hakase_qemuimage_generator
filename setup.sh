#!/bin/bash -xe
sudo su -c :

SSH="ssh -o LogLevel=quiet -o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -p 2222 -i id_rsa ubuntu@localhost"

function wait_until_ssh_ready() {
    while ! ${SSH} -o ConnectTimeout=3 "exit 0"; do sleep 1; done
}

function kill_qemu() {
    sudo pkill qemu-system-x86 || :
}

if [ ! -e ubuntu-16.04-server-cloudimg-amd64-disk1.img ]; then
    wget https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
fi
cp ubuntu-16.04-server-cloudimg-amd64-disk1.img work/
cd work

trap 'rm ubuntu-16.04-server-cloudimg-amd64-disk1.img' SIGINT ERR
kill_qemu
cloud-localds -d qcow2 cloud.qcow2 ../cloud-config.yml

trap SIGINT ERR
trap 'kill_qemu; rm ubuntu-16.04-server-cloudimg-amd64-disk1.img' SIGINT ERR

sudo qemu-system-x86_64 -cpu Haswell -nographic -hda ubuntu-16.04-server-cloudimg-amd64-disk1.img -hdb cloud.qcow2 -smp 5 -m 4G -net nic -net user,hostfwd=tcp::2222-:22 -enable-kvm > /dev/null 2>&1 &
wait_until_ssh_ready
${SSH} "bash -s" < ../install_script
${SSH} "sudo poweroff" || :

while pgrep qemu-system-x86; do sleep 1; done
qemu-img convert -O qcow2 ubuntu-16.04-server-cloudimg-amd64-disk1.img ubuntu-16.04-server-cloudimg-amd64-disk1.qcow2

qemu-system-x86_64 -cpu Haswell -nographic -hda ubuntu-16.04-server-cloudimg-amd64-disk1.qcow2 -hdb cloud.qcow2 -smp 5 -m 4G -net nic -net user,hostfwd=tcp::2222-:22 -serial telnet:127.0.0.1:4444,server,nowait -monitor telnet:127.0.0.1:4445,server,nowait > /dev/null 2>&1 &
sleep 5
expect -c "
set timeout -1
spawn telnet localhost 4444
expect \"ubuntu login:\"
"
echo "stop" | netcat localhost 4445
echo "savevm snapshot1" | netcat localhost 4445
echo "quit" | netcat localhost 4445

rm ubuntu-16.04-server-cloudimg-amd64-disk1.img
trap SIGINT ERR

FINAL=hakase_qemuimage_$(openssl rand -base64 24).tar.xz
tar Jcvf ${FINAL} .
mv ${FINAL} ..

echo "setup done!"
