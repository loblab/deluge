#!/bin/bash
# Copyright 2017 loblab
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
PROG_DIR=$(dirname $0)
[ "$(whoami)" == "root" ] || SUDO=sudo

function log_msg() {
    echo $(date +'%m/%d %H:%M:%S') - $*
}

function install_system_packages() {
    log_msg "Install system packages..."
    $SUDO apt -y install deluged deluge-web
    log_msg "Install system packages... done."
}

function cleanup_default_installation() {
    log_msg "Cleanup default installation..."
    if [ -f /etc/init.d/deluged ]; then
        $SUDO /etc/init.d/deluged stop
        $SUDO rm /etc/init.d/deluged
        $SUDO update-rc.d deluged remove
    fi
 
    $SUDO rm -rf /var/log/deluged
    $SUDO rm -f /etc/logrotate.d/deluged
    log_msg "Cleanup default installation... done"
}

function setup_user() {
    log_msg "Setup deluge user/group..."
    if id "deluge" >/dev/null 2>&1; then
        echo "User 'deluge' exists, nothing to do"
        return 0
    fi
    if id "debian-deluged" >/dev/null 2>&1; then
        log_msg "Delete user/group 'debian-deluged'..."
        $SUDO deluser debian-deluged
        #$SUDO delgroup debian-deluged
        $SUDO sed -i '/debian-deluged/d' /var/lib/dpkg/statoverride
    fi
    log_msg "Create user/group 'deluge'..."
    $SUDO adduser --system  --gecos "Deluge Service" --disabled-password --group --home /var/lib/deluge deluge
    log_msg "Add $MY_ACCOUNT to group 'deluge'"
    $SUDO adduser $MY_ACCOUNT deluge
    log_msg "Setup deluge user/group... done"
}

function setup_service() {
    log_msg "Install deluge services..."
 
    $SUDO mkdir -p /var/log/deluge
    $SUDO chown -R deluge:deluge /var/log/deluge
    $SUDO chmod -R 750 /var/log/deluge

    $SUDO cp $PROG_DIR/*.service /etc/systemd/system/
    $SUDO cp $PROG_DIR/logrotate.conf /etc/logrotate.d/deluge

    $SUDO systemctl enable deluged
    $SUDO systemctl enable deluge-web
    log_msg "Install deluge services... done"

    log_msg "Start deluge services..."
    $SUDO systemctl start deluged
    $SUDO systemctl status deluged
    $SUDO systemctl start deluge-web
    $SUDO systemctl status deluge-web
    log_msg "Start deluge services... done"
}

function main() {
    MY_ACCOUNT=$(id -un)
    install_system_packages
    cleanup_default_installation
    setup_user
    setup_service
    addr=$(hostname -I | sed 's/ //g')
    log_msg "Succeeded. Please access http://$addr:8112/ (password: deluge)"
}

main

