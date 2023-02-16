# Custom Script for Linux

#!/bin/bash

# The MIT License (MIT)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
set -ex
echo "### Script Start `date`###"


function get_setup_params_from_configs_json
{
    local configs_json_path=${1}    # E.g., /var/lib/cloud/instance/moodle_on_azure_configs.json

    # (dpkg -l jq &> /dev/null) || (apt -y update; apt -y install jq)
    # sudo add-apt-repository universe
    # sudo apt-get -y update
    # sudo apt-get -y install jq

    # Added curl command to download jq.
    curl https://stedolan.github.io/jq/download/linux64/jq > /usr/bin/jq && chmod +x /usr/bin/jq
	
    # Wait for the cloud-init write-files user data file to be generated (just in case)
    local wait_time_sec=0
    while [ ! -f "$configs_json_path" ]; do
        sleep 15
        let "wait_time_sec += 15"
        if [ "$wait_time_sec" -ge "1800" ]; then
            echo "Error: Cloud-init write-files didn't complete in 30 minutes!"
            return 1
        fi
    done

    local json=$(cat $configs_json_path)
    export moodleVersion=$(echo $json | jq -r .moodleProfile.version)
    export glusterNode=$(echo $json | jq -r .fileServerProfile.glusterVmName)
    export glusterVolume=$(echo $json | jq -r .fileServerProfile.glusterVolName)
    export siteFQDN=$(echo $json | jq -r .siteProfile.siteURL)
    export httpsTermination=$(echo $json | jq -r .siteProfile.httpsTermination)
    export dbIP=$(echo $json | jq -r .dbServerProfile.fqdn)
    export moodledbname=$(echo $json | jq -r .moodleProfile.dbName)
    export moodledbuser=$(echo $json | jq -r .moodleProfile.dbUser)
    export moodledbpass=$(echo $json | jq -r .moodleProfile.dbPassword)
    export adminpass=$(echo $json | jq -r .moodleProfile.adminPassword)
    export dbadminlogin=$(echo $json | jq -r .dbServerProfile.adminLogin)
    export dbadminloginazure=$(echo $json | jq -r .dbServerProfile.adminLoginAzure)
    export dbadminpass=$(echo $json | jq -r .dbServerProfile.adminPassword)
    export storageAccountName=$(echo $json | jq -r .moodleProfile.storageAccountName)
    export storageAccountKey=$(echo $json | jq -r .moodleProfile.storageAccountKey)
    export azuremoodledbuser=$(echo $json | jq -r .moodleProfile.dbUserAzure)
    export redisDns=$(echo $json | jq -r .moodleProfile.redisDns)
    export redisAuth=$(echo $json | jq -r .moodleProfile.redisKey)
    export elasticVm1IP=$(echo $json | jq -r .moodleProfile.elasticVm1IP)
    export installO365pluginsSwitch=$(echo $json | jq -r .moodleProfile.installO365pluginsSwitch)
    export dbServerType=$(echo $json | jq -r .dbServerProfile.type)
    export fileServerType=$(echo $json | jq -r .fileServerProfile.type)
    export mssqlDbServiceObjectiveName=$(echo $json | jq -r .dbServerProfile.mssqlDbServiceObjectiveName)
    export mssqlDbEdition=$(echo $json | jq -r .dbServerProfile.mssqlDbEdition)
    export mssqlDbSize=$(echo $json | jq -r .dbServerProfile.mssqlDbSize)
    export installObjectFsSwitch=$(echo $json | jq -r .moodleProfile.installObjectFsSwitch)
    export installGdprPluginsSwitch=$(echo $json | jq -r .moodleProfile.installGdprPluginsSwitch)
    export thumbprintSslCert=$(echo $json | jq -r .siteProfile.thumbprintSslCert)
    export thumbprintCaCert=$(echo $json | jq -r .siteProfile.thumbprintCaCert)
    export searchType=$(echo $json | jq -r .moodleProfile.searchType)
    export azureSearchKey=$(echo $json | jq -r .moodleProfile.azureSearchKey)
    export azureSearchNameHost=$(echo $json | jq -r .moodleProfile.azureSearchNameHost)
    export tikaVmIP=$(echo $json | jq -r .moodleProfile.tikaVmIP)
    export syslogServer=$(echo $json | jq -r .moodleProfile.syslogServer)
    export webServerType=$(echo $json | jq -r .moodleProfile.webServerType)
    export htmlLocalCopySwitch=$(echo $json | jq -r .moodleProfile.htmlLocalCopySwitch)
    export nfsVmName=$(echo $json | jq -r .fileServerProfile.nfsVmName)
    export nfsHaLbIP=$(echo $json | jq -r .fileServerProfile.nfsHaLbIP)
    export nfsHaExportPath=$(echo $json | jq -r .fileServerProfile.nfsHaExportPath)
    export nfsByoIpExportPath=$(echo $json | jq -r .fileServerProfile.nfsByoIpExportPath)
    export storageAccountType=$(echo $json | jq -r .moodleProfile.storageAccountType)
    export fileServerDiskSize=$(echo $json | jq -r .fileServerProfile.fileServerDiskSize)
    export phpVersion=$(echo $json | jq -r .phpProfile.phpVersion)
    export isMigration=$(echo $json | jq -r .moodleProfile.isMigration)
}

function get_php_version {
# Returns current PHP version, in the form of x.x, eg 7.0 or 7.2
    if [ -z "$_PHPVER" ]; then
        _PHPVER=`/usr/bin/php -r "echo PHP_VERSION;" | /usr/bin/cut -c 1,2,3`
    fi
    echo $_PHPVER
}

function install_php_mssql_driver
{
    # Download and build php/mssql driver
    /usr/bin/curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
    /usr/bin/curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
    sudo apt-get update
    sudo ACCEPT_EULA=Y apt-get install msodbcsql mssql-tools unixodbc-dev -y
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
    source ~/.bashrc

    #Build mssql driver
    /usr/bin/pear config-set php_ini `php --ini | grep "Loaded Configuration" | sed -e "s|.*:\s*||"` system
    /usr/bin/pecl install sqlsrv
    /usr/bin/pecl install pdo_sqlsrv
    PHPVER=$(get_php_version)
    echo "extension=sqlsrv.so" >> /etc/php/$PHPVER/fpm/php.ini
    echo "extension=pdo_sqlsrv.so" >> /etc/php/$PHPVER/fpm/php.ini
    echo "extension=sqlsrv.so" >> /etc/php/$PHPVER/apache2/php.ini
    echo "extension=pdo_sqlsrv.so" >> /etc/php/$PHPVER/apache2/php.ini
    echo "extension=sqlsrv.so" >> /etc/php/$PHPVER/cli/php.ini
    echo "extension=pdo_sqlsrv.so" >> /etc/php/$PHPVER/cli/php.ini
}

function check_fileServerType_param
{
    local fileServerType=$1
    if [ "$fileServerType" != "gluster" -a "$fileServerType" != "azurefiles" -a "$fileServerType" != "nfs" -a "$fileServerType" != "nfs-ha" -a "$fileServerType" != "nfs-byo" ]; then
        echo "Invalid fileServerType ($fileServerType) given. Only 'gluster', 'azurefiles', 'nfs', 'nfs-ha' or 'nfs-byo' are allowed. Exiting"
        exit 1
    fi
}

function create_azure_files_moodle_share
{
    local storageAccountName=$1
    local storageAccountKey=$2
    local logFilePath=$3
    local fileServerDiskSize=$4

    az storage share create \
        --name moodle \
        --account-name $storageAccountName \
        --account-key $storageAccountKey \
        --fail-on-exist >>$logFilePath \
        --quota $fileServerDiskSize
}

function replace_config_setting_value
{
    local setting_name=$1
    local setting_value=$2
    local delemeter=$3
    local file_name=$4

    echo "Replacing $setting_name $delemeter $setting_value in $file_name"

    sed -i "s/^\($setting_name\s*$delemeter\s*\).*\$/\1$setting_value/" $file_name
}

# This function can replace only single line $CFG setting in moodle/config.php file.
# Supported config setting format:
#      $CFG->setting = 'value';
# Usage:
#      replace_moodle_config_value "setting" "value"
function replace_moodle_config_value
{
    local formated_setting_name="\$CFG->$1"
    local formated_setting_value="'$2';"
    local delemeter="="
    local moodle_config_file=/moodle/html/moodle/config.php
    
    replace_config_setting_value $formated_setting_name $formated_setting_value $delemeter $moodle_config_file
}

function check_azure_files_moodle_share_exists
{
    local storageAccountName=$1
    local storageAccountKey=$2

    local azResponse=$(az storage share exists --name moodle --account-name $storageAccountName --account-key $storageAccountKey)
    if [ $? -ne 0 ];then
      echo "Could not check if moodle file share exists in the storage account ($storageAccountName)"
      exit 1
    fi

    echo "az storage share exists command response:"
    echo $azResponse
    #Sample 'az storage share exists' command response
    # { "exists": true }
    local exists=$(echo $azResponse | jq -r .exists)

    if [ "$exists" != "true" ];then
      echo "File share 'moodle' does not exists in the storage account ($storageAccountName)"
      exit 1
    fi
}

function setup_and_mount_gluster_moodle_share
{
    local glusterNode=$1
    local glusterVolume=$2

    grep -q "/moodle.*glusterfs" /etc/fstab || echo -e $glusterNode':/'$glusterVolume'   /moodle         glusterfs       defaults,_netdev,log-level=WARNING,log-file=/var/log/gluster.log 0 0' >> /etc/fstab
    mount /moodle
}

function setup_and_mount_azure_files_moodle_share
{
    local storageAccountName=$1
    local storageAccountKey=$2

    cat <<EOF > /etc/moodle_azure_files.credential
username=$storageAccountName
password=$storageAccountKey
EOF
    chmod 600 /etc/moodle_azure_files.credential
    
    grep -q -s "^//$storageAccountName.file.core.windows.net/moodle\s\s*/moodle\s\s*cifs" /etc/fstab && _RET=$? || _RET=$?
    if [ $_RET != "0" ]; then
        echo -e "\n//$storageAccountName.file.core.windows.net/moodle   /moodle cifs    credentials=/etc/moodle_azure_files.credential,uid=www-data,gid=www-data,nofail,vers=3.0,dir_mode=0770,file_mode=0660,serverino,mfsymlinks" >> /etc/fstab
    fi
    mkdir -p /moodle
    mount /moodle
}

function setup_moodle_mount_dependency_for_systemd_service
{
  local serviceName=$1 # E.g., nginx, apache2
  if [ -z "$serviceName" ]; then
    return 1
  fi

  local systemdSvcOverrideFileDir="/etc/systemd/system/${serviceName}.service.d"
  local systemdSvcOverrideFilePath="${systemdSvcOverrideFileDir}/moodle_on_azure_override.conf"

  grep -q -s "After=moodle.mount" $systemdSvcOverrideFilePath && _RET=$? || _RET=$?
  if [ $_RET != "0" ]; then
    mkdir -p $systemdSvcOverrideFileDir
    cat <<EOF > $systemdSvcOverrideFilePath
[Unit]
After=moodle.mount

[Service]
LimitNOFILE=100000
EOF
    systemctl daemon-reload
  fi
}

# Functions for making NFS share available
# TODO refactor these functions with the same ones in install_gluster.sh
function scan_for_new_disks
{
    local BLACKLIST=${1}    # E.g., /dev/sda|/dev/sdb
    declare -a RET
    local DEVS=$(ls -1 /dev/sd*|egrep -v "${BLACKLIST}"|egrep -v "[0-9]$")
    for DEV in ${DEVS};
    do
        # Check each device if there is a "1" partition.  If not,
        # "assume" it is not partitioned.
        if [ ! -b ${DEV}1 ];
        then
            RET+="${DEV} "
        fi
    done
    echo "${RET}"
}

function create_raid0_ubuntu {
    local RAIDDISK=${1}       # E.g., /dev/md1
    local RAIDCHUNKSIZE=${2}  # E.g., 128
    local DISKCOUNT=${3}      # E.g., 4
    shift
    shift
    shift
    local DISKS="$@"

    dpkg -s mdadm && _RET=$? || _RET=$?
    if [ $_RET -eq 1 ];
    then 
        echo "installing mdadm"
        sudo apt-get -y -q install mdadm
    fi
    echo "Creating raid0"
    udevadm control --stop-exec-queue
    echo "yes" | mdadm --create $RAIDDISK --name=data --level=0 --chunk=$RAIDCHUNKSIZE --raid-devices=$DISKCOUNT $DISKS
    udevadm control --start-exec-queue
    mdadm --detail --verbose --scan > /etc/mdadm/mdadm.conf
}

function do_partition {
    # This function creates one (1) primary partition on the
    # disk device, using all available space
    local DISK=${1}   # E.g., /dev/sdc

    echo "Partitioning disk $DISK"
    echo -ne "n\np\n1\n\n\nw\n" | fdisk "${DISK}" 
    #> /dev/null 2>&1

    #
    # Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
    # from fdisk and not from echo
    if [ ${PIPESTATUS[1]} -ne 0 ];
    then
        echo "An error occurred partitioning ${DISK}" >&2
        echo "I cannot continue" >&2
        exit 2
    fi
}

function add_local_filesystem_to_fstab {
    local UUID=${1}
    local MOUNTPOINT=${2}   # E.g., /moodle

    grep -q -s "${UUID}" /etc/fstab && _RET=$? || _RET=$?
    if [ $_RET -eq 0 ];
    then
        echo "Not adding ${UUID} to fstab again (it's already there!)"
    else
        LINE="\nUUID=${UUID} ${MOUNTPOINT} ext4 defaults,noatime 0 0"
        echo -e "${LINE}" >> /etc/fstab
    fi
}

function setup_raid_disk_and_filesystem {
    local MOUNTPOINT=${1}     # E.g., /moodle
    local RAIDDISK=${2}       # E.g., /dev/md1
    local RAIDPARTITION=${3}  # E.g., /dev/md1p1
    local CREATE_FILESYSTEM=${4}  # E.g., "" (true) or any non-empty string (false)

    local DISKS=$(scan_for_new_disks "/dev/sda|/dev/sdb")
    echo "Disks are ${DISKS}"
    declare -i DISKCOUNT
    local DISKCOUNT=$(echo "$DISKS" | wc -w) 
    echo "Disk count is $DISKCOUNT"
    if [ $DISKCOUNT = "0" ]; then
        echo "No new (unpartitioned) disks available... Returning non-zero..."
        return 1
    fi

    if [ $DISKCOUNT -gt 1 ]; then
        create_raid0_ubuntu ${RAIDDISK} 128 $DISKCOUNT $DISKS
        AZMDL_DISK=$RAIDDISK
        if [ -z "$CREATE_FILESYSTEM" ]; then
          do_partition ${RAIDDISK}
          local PARTITION="${RAIDPARTITION}"
        fi
    else # Just one unpartitioned disk
        AZMDL_DISK=$DISKS
        if [ -z "$CREATE_FILESYSTEM" ]; then
          do_partition ${DISKS}
          local PARTITION=$(fdisk -l ${DISKS}|grep -A 1 Device|tail -n 1|awk '{print $1}')
        fi
    fi

    echo "Disk (RAID if multiple unpartitioned disks, or as is if only one unpartitioned disk) is set up, and env var AZMDL_DISK is set to '$AZMDL_DISK' for later reference"

    if [ -z "$CREATE_FILESYSTEM" ]; then
      echo "Creating filesystem on ${PARTITION}."
      mkfs -t ext4 ${PARTITION}
      mkdir -p "${MOUNTPOINT}"
      local UUID=$(blkid -u filesystem ${PARTITION}|awk -F "[= ]" '{print $3}'|tr -d "\"")
      add_local_filesystem_to_fstab "${UUID}" "${MOUNTPOINT}"
      echo "Mounting disk ${PARTITION} on ${MOUNTPOINT}"
      mount "${MOUNTPOINT}"
    fi
}

function configure_nfs_server_and_export {
    local MOUNTPOINT=${1}     # E.g., /moodle

    echo "Installing nfs server..."
    apt install -y nfs-kernel-server

    echo "Exporting ${MOUNTPOINT}..."
    grep -q -s "^${MOUNTPOINT}" /etc/exports && _RET=$? || _RET=$?
    if [ $_RET = "0" ]; then
        echo "${MOUNTPOINT} is already exported. Returning..."
    else
        echo -e "\n${MOUNTPOINT}   *(rw,sync,no_root_squash)" >> /etc/exports
        systemctl restart nfs-kernel-server.service
    fi
}

function configure_nfs_client_and_mount0 {
    local NFS_HOST_EXPORT_PATH=${1}   # E.g., controller-vm-ab12cd:/moodle or 172.16.3.100:/drbd/data
    local MOUNTPOINT=${2}             # E.g., /moodle

    apt install -y nfs-common
    mkdir -p ${MOUNTPOINT}

    grep -q -s "^${NFS_HOST_EXPORT_PATH}" /etc/fstab && _RET=$? || _RET=$?
    if [ $_RET = "0" ]; then
        echo "${NFS_HOST_EXPORT_PATH} already in /etc/fstab... skipping to add"
    else
        echo -e "\n${NFS_HOST_EXPORT_PATH}    ${MOUNTPOINT}    nfs    auto    0    0" >> /etc/fstab
    fi
    mount ${MOUNTPOINT}
}

function configure_nfs_client_and_mount {
    local NFS_SERVER=${1}     # E.g., controller-vm-ab12cd or IP (NFS-HA LB)
    local NFS_DIR=${2}        # E.g., /moodle or /drbd/data
    local MOUNTPOINT=${3}     # E.g., /moodle

    configure_nfs_client_and_mount0 "${NFS_SERVER}:${NFS_DIR}" ${MOUNTPOINT}
}

SERVER_TIMESTAMP_FULLPATH="/moodle/html/moodle/.last_modified_time.moodle_on_azure"
LOCAL_TIMESTAMP_FULLPATH="/var/www/html/moodle/.last_modified_time.moodle_on_azure"

# Create a script to sync /moodle/html/moodle (gluster/NFS) and /var/www/html/moodle (local) and set up a minutely cron job
# Should be called by root and only on a VMSS web frontend VM
function setup_html_local_copy_cron_job {
  if [ "$(whoami)" != "root" ]; then
    echo "${0}: Must be run as root!"
    return 1
  fi

  local SYNC_SCRIPT_FULLPATH="/usr/local/bin/sync_moodle_html_local_copy_if_modified.sh"
  mkdir -p $(dirname ${SYNC_SCRIPT_FULLPATH})

  local SYNC_LOG_FULLPATH="/var/log/moodle-html-sync.log"

  cat <<EOF > ${SYNC_SCRIPT_FULLPATH}
#!/bin/bash

sleep \$((\$RANDOM%30))

if [ -f "$SERVER_TIMESTAMP_FULLPATH" ]; then
  SERVER_TIMESTAMP=\$(cat $SERVER_TIMESTAMP_FULLPATH)
  if [ -f "$LOCAL_TIMESTAMP_FULLPATH" ]; then
    LOCAL_TIMESTAMP=\$(cat $LOCAL_TIMESTAMP_FULLPATH)
  else
    logger -p local2.notice -t moodle "Local timestamp file ($LOCAL_TIMESTAMP_FULLPATH) does not exist. Probably first time syncing? Continuing to sync."
    mkdir -p /var/www/html
  fi
  if [ "\$SERVER_TIMESTAMP" != "\$LOCAL_TIMESTAMP" ]; then
    logger -p local2.notice -t moodle "Server time stamp (\$SERVER_TIMESTAMP) is different from local time stamp (\$LOCAL_TIMESTAMP). Start syncing..."
    if [[ \$(find $SYNC_LOG_FULLPATH -type f -size +20M 2> /dev/null) ]]; then
      truncate -s 0 $SYNC_LOG_FULLPATH
    fi
    echo \$(date +%Y%m%d%H%M%S) >> $SYNC_LOG_FULLPATH
    rsync -av --delete /moodle/html/moodle /var/www/html >> $SYNC_LOG_FULLPATH
  fi
else
  logger -p local2.notice -t moodle "Remote timestamp file ($SERVER_TIMESTAMP_FULLPATH) does not exist. Is /moodle mounted? Exiting with error."
  exit 1
fi
EOF
  chmod 500 ${SYNC_SCRIPT_FULLPATH}

  local CRON_DESC_FULLPATH="/etc/cron.d/sync-moodle-html-local-copy"
  cat <<EOF > ${CRON_DESC_FULLPATH}
* * * * * root ${SYNC_SCRIPT_FULLPATH}
EOF
  chmod 644 ${CRON_DESC_FULLPATH}

  # Addition of a hook for custom script run on VMSS from shared mount to allow customised configuration of the VMSS as required
  local CRON_DESC_FULLPATH2="/etc/cron.d/update-vmss-config"
  cat <<EOF > ${CRON_DESC_FULLPATH2}
* * * * * root [ -f /moodle/bin/update-vmss-config ] && /bin/bash /moodle/bin/update-vmss-config
EOF
  chmod 644 ${CRON_DESC_FULLPATH2}
}

LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH="/usr/local/bin/update_last_modified_time.moodle_on_azure.sh"

# Create a script to modify the last modified timestamp file (/moodle/html/moodle/last_modified_time.moodle_on_azure)
# Should be called by root and only on the controller VM.
# The moodle admin should run the generated script everytime the /moodle/html/moodle directory content is updated (e.g., moodle upgrade, config change or plugin install/upgrade)
function create_last_modified_time_update_script {
  if [ "$(whoami)" != "root" ]; then
    echo "${0}: Must be run as root!"
    return 1
  fi

  mkdir -p $(dirname $LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH)
  cat <<EOF > $LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH
#!/bin/bash
echo \$(date +%Y%m%d%H%M%S) > $SERVER_TIMESTAMP_FULLPATH
EOF

  chmod +x $LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH
}

function run_once_last_modified_time_update_script {
  $LAST_MODIFIED_TIME_UPDATE_SCRIPT_FULLPATH
}

# O365 plugins are released only for 'MOODLE_xy_STABLE',
# whereas we want to support the Moodle tagged versions (e.g., 'v3.4.2').
# This function helps getting the stable version # (for O365 plugin ver.)
# from a Moodle version tag. This utility function recognizes tag names
# of the form 'vx.y.z' only.
function get_o365plugin_version_from_moodle_version {
  local moodleVersion=${1}
  if [[ "$moodleVersion" =~ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    echo "MOODLE_${BASH_REMATCH[1]}${BASH_REMATCH[2]}_STABLE"
  else
    echo $moodleVersion
  fi
}

# For Moodle tags (e.g., "v3.4.2"), the unzipped Moodle dir is no longer
# "moodle-$moodleVersion", because for tags, it's without "v". That is,
# it's "moodle-3.4.2". Therefore, we need a separate helper function for that...
function get_moodle_unzip_dir_from_moodle_version {
  local moodleVersion=${1}
  if [[ "$moodleVersion" =~ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    echo "moodle-${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  else
    echo "moodle-$moodleVersion"
  fi
}

# Long Redis cache Moodle config file generation code moved here
function create_redis_configuration_in_moodledata_muc_config_php
{
    # create redis configuration in /moodle/moodledata/muc/config.php
    cat <<EOF > /moodle/moodledata/muc/config.php
<?php defined('MOODLE_INTERNAL') || die();
 \$configuration = array (
  'siteidentifier' => '7a142be09ea65699e4a6f6ef91c0773c',
  'stores' => 
  array (
    'default_application' => 
    array (
      'name' => 'default_application',
      'plugin' => 'file',
      'configuration' => 
      array (
      ),
      'features' => 30,
      'modes' => 3,
      'default' => true,
      'class' => 'cachestore_file',
      'lock' => 'cachelock_file_default',
    ),
    'default_session' => 
    array (
      'name' => 'default_session',
      'plugin' => 'session',
      'configuration' => 
      array (
      ),
      'features' => 14,
      'modes' => 2,
      'default' => true,
      'class' => 'cachestore_session',
      'lock' => 'cachelock_file_default',
    ),
    'default_request' => 
    array (
      'name' => 'default_request',
      'plugin' => 'static',
      'configuration' => 
      array (
      ),
      'features' => 31,
      'modes' => 4,
      'default' => true,
      'class' => 'cachestore_static',
      'lock' => 'cachelock_file_default',
    ),
    'redis' => 
    array (
      'name' => 'redis',
      'plugin' => 'redis',
      'configuration' => 
      array (
        'server' => '$redisDns',
        'prefix' => 'moodle_prod',
        'password' => '$redisAuth',
        'serializer' => '1',
      ),
      'features' => 26,
      'modes' => 3,
      'mappingsonly' => false,
      'class' => 'cachestore_redis',
      'default' => false,
      'lock' => 'cachelock_file_default',
    ),
    'local_file' => 
    array (
      'name' => 'local_file',
      'plugin' => 'file',
      'configuration' => 
      array (
        'path' => '/tmp/muc/moodle_prod',
        'autocreate' => 1,
      ),
      'features' => 30,
      'modes' => 3,
      'mappingsonly' => false,
      'class' => 'cachestore_file',
      'default' => false,
      'lock' => 'cachelock_file_default',
    ),
  ),
  'modemappings' => 
  array (
    0 => 
    array (
      'store' => 'redis',
      'mode' => 1,
      'sort' => 0,
    ),
    1 => 
    array (
      'store' => 'default_session',
      'mode' => 2,
      'sort' => 0,
    ),
    2 => 
    array (
      'store' => 'default_request',
      'mode' => 4,
      'sort' => 0,
    ),
  ),
  'definitions' => 
  array (
    'core/string' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 30,
      'canuselocalstore' => true,
      'component' => 'core',
      'area' => 'string',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/langmenu' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'canuselocalstore' => true,
      'component' => 'core',
      'area' => 'langmenu',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/databasemeta' => 
    array (
      'mode' => 1,
      'requireidentifiers' => 
      array (
        0 => 'dbfamily',
      ),
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 15,
      'component' => 'core',
      'area' => 'databasemeta',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/eventinvalidation' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'requiredataguarantee' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'eventinvalidation',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/questiondata' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'requiredataguarantee' => false,
      'datasource' => 'question_finder',
      'datasourcefile' => 'question/engine/bank.php',
      'component' => 'core',
      'area' => 'questiondata',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/htmlpurifier' => 
    array (
      'mode' => 1,
      'canuselocalstore' => true,
      'component' => 'core',
      'area' => 'htmlpurifier',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/config' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'config',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/groupdata' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'component' => 'core',
      'area' => 'groupdata',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/calendar_subscriptions' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'component' => 'core',
      'area' => 'calendar_subscriptions',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/capabilities' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'ttl' => 3600,
      'component' => 'core',
      'area' => 'capabilities',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/yuimodules' => 
    array (
      'mode' => 1,
      'component' => 'core',
      'area' => 'yuimodules',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/observers' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'component' => 'core',
      'area' => 'observers',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/plugin_manager' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'plugin_manager',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/coursecattree' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'invalidationevents' => 
      array (
        0 => 'changesincoursecat',
      ),
      'component' => 'core',
      'area' => 'coursecattree',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/coursecat' => 
    array (
      'mode' => 2,
      'invalidationevents' => 
      array (
        0 => 'changesincoursecat',
        1 => 'changesincourse',
      ),
      'ttl' => 600,
      'component' => 'core',
      'area' => 'coursecat',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/coursecatrecords' => 
    array (
      'mode' => 4,
      'simplekeys' => true,
      'invalidationevents' => 
      array (
        0 => 'changesincoursecat',
      ),
      'component' => 'core',
      'area' => 'coursecatrecords',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/coursecontacts' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'simplekeys' => true,
      'ttl' => 3600,
      'component' => 'core',
      'area' => 'coursecontacts',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/repositories' => 
    array (
      'mode' => 4,
      'component' => 'core',
      'area' => 'repositories',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/externalbadges' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'ttl' => 3600,
      'component' => 'core',
      'area' => 'externalbadges',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/coursemodinfo' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'canuselocalstore' => true,
      'component' => 'core',
      'area' => 'coursemodinfo',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/userselections' => 
    array (
      'mode' => 2,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'userselections',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/completion' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'ttl' => 3600,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'component' => 'core',
      'area' => 'completion',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/coursecompletion' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'ttl' => 3600,
      'staticacceleration' => true,
      'staticaccelerationsize' => 30,
      'component' => 'core',
      'area' => 'coursecompletion',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/navigation_expandcourse' => 
    array (
      'mode' => 2,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'navigation_expandcourse',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/suspended_userids' => 
    array (
      'mode' => 4,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'suspended_userids',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/roledefs' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 30,
      'component' => 'core',
      'area' => 'roledefs',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/plugin_functions' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 5,
      'component' => 'core',
      'area' => 'plugin_functions',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/tags' => 
    array (
      'mode' => 4,
      'simplekeys' => true,
      'staticacceleration' => true,
      'component' => 'core',
      'area' => 'tags',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/grade_categories' => 
    array (
      'mode' => 2,
      'simplekeys' => true,
      'invalidationevents' => 
      array (
        0 => 'changesingradecategories',
      ),
      'component' => 'core',
      'area' => 'grade_categories',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/temp_tables' => 
    array (
      'mode' => 4,
      'simplekeys' => true,
      'simpledata' => true,
      'component' => 'core',
      'area' => 'temp_tables',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/tagindexbuilder' => 
    array (
      'mode' => 2,
      'simplekeys' => true,
      'simplevalues' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 10,
      'ttl' => 900,
      'invalidationevents' => 
      array (
        0 => 'resettagindexbuilder',
      ),
      'component' => 'core',
      'area' => 'tagindexbuilder',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'core/contextwithinsights' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'core',
      'area' => 'contextwithinsights',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/message_processors_enabled' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 3,
      'component' => 'core',
      'area' => 'message_processors_enabled',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/message_time_last_message_between_users' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simplevalues' => true,
      'datasource' => '\\core_message\\time_last_message_between_users',
      'component' => 'core',
      'area' => 'message_time_last_message_between_users',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/fontawesomeiconmapping' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'core',
      'area' => 'fontawesomeiconmapping',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/postprocessedcss' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => false,
      'component' => 'core',
      'area' => 'postprocessedcss',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'core/user_group_groupings' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'component' => 'core',
      'area' => 'user_group_groupings',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'availability_grade/scores' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'ttl' => 3600,
      'component' => 'availability_grade',
      'area' => 'scores',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'availability_grade/items' => 
    array (
      'mode' => 1,
      'staticacceleration' => true,
      'staticaccelerationsize' => 2,
      'ttl' => 3600,
      'component' => 'availability_grade',
      'area' => 'items',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'mod_glossary/concepts' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => false,
      'staticacceleration' => true,
      'staticaccelerationsize' => 30,
      'component' => 'mod_glossary',
      'area' => 'concepts',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'repository_googledocs/folder' => 
    array (
      'mode' => 1,
      'simplekeys' => false,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 10,
      'canuselocalstore' => true,
      'component' => 'repository_googledocs',
      'area' => 'folder',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'repository_onedrive/folder' => 
    array (
      'mode' => 1,
      'simplekeys' => false,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 10,
      'canuselocalstore' => true,
      'component' => 'repository_onedrive',
      'area' => 'folder',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'repository_skydrive/foldername' => 
    array (
      'mode' => 2,
      'component' => 'repository_skydrive',
      'area' => 'foldername',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'tool_mobile/plugininfo' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'tool_mobile',
      'area' => 'plugininfo',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'tool_monitor/eventsubscriptions' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 10,
      'component' => 'tool_monitor',
      'area' => 'eventsubscriptions',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'tool_uploadcourse/helper' => 
    array (
      'mode' => 4,
      'component' => 'tool_uploadcourse',
      'area' => 'helper',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 2,
    ),
    'tool_usertours/tourdata' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'tool_usertours',
      'area' => 'tourdata',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
    'tool_usertours/stepdata' => 
    array (
      'mode' => 1,
      'simplekeys' => true,
      'simpledata' => true,
      'staticacceleration' => true,
      'staticaccelerationsize' => 1,
      'component' => 'tool_usertours',
      'area' => 'stepdata',
      'selectedsharingoption' => 2,
      'userinputsharingkey' => '',
      'sharingoptions' => 15,
    ),
  ),
  'definitionmappings' => 
  array (
    0 => 
    array (
      'store' => 'local_file',
      'definition' => 'core/coursemodinfo',
      'sort' => 1,
    ),
    1 => 
    array (
      'store' => 'redis',
      'definition' => 'core/groupdata',
      'sort' => 1,
    ),
    2 => 
    array (
      'store' => 'redis',
      'definition' => 'core/roledefs',
      'sort' => 1,
    ),
    3 => 
    array (
      'store' => 'redis',
      'definition' => 'tool_usertours/tourdata',
      'sort' => 1,
    ),
    4 => 
    array (
      'store' => 'redis',
      'definition' => 'repository_onedrive/folder',
      'sort' => 1,
    ),
    5 => 
    array (
      'store' => 'redis',
      'definition' => 'core/message_processors_enabled',
      'sort' => 1,
    ),
    6 => 
    array (
      'store' => 'redis',
      'definition' => 'core/coursecontacts',
      'sort' => 1,
    ),
    7 => 
    array (
      'store' => 'redis',
      'definition' => 'repository_googledocs/folder',
      'sort' => 1,
    ),
    8 => 
    array (
      'store' => 'redis',
      'definition' => 'core/questiondata',
      'sort' => 1,
    ),
    9 => 
    array (
      'store' => 'redis',
      'definition' => 'core/coursecat',
      'sort' => 1,
    ),
    10 => 
    array (
      'store' => 'redis',
      'definition' => 'core/databasemeta',
      'sort' => 1,
    ),
    11 => 
    array (
      'store' => 'redis',
      'definition' => 'core/eventinvalidation',
      'sort' => 1,
    ),
    12 => 
    array (
      'store' => 'redis',
      'definition' => 'core/coursecattree',
      'sort' => 1,
    ),
    13 => 
    array (
      'store' => 'redis',
      'definition' => 'core/coursecompletion',
      'sort' => 1,
    ),
    14 => 
    array (
      'store' => 'redis',
      'definition' => 'core/user_group_groupings',
      'sort' => 1,
    ),
    15 => 
    array (
      'store' => 'redis',
      'definition' => 'core/capabilities',
      'sort' => 1,
    ),
    16 => 
    array (
      'store' => 'redis',
      'definition' => 'core/yuimodules',
      'sort' => 1,
    ),
    17 => 
    array (
      'store' => 'redis',
      'definition' => 'core/observers',
      'sort' => 1,
    ),
    18 => 
    array (
      'store' => 'redis',
      'definition' => 'mod_glossary/concepts',
      'sort' => 1,
    ),
    19 => 
    array (
      'store' => 'redis',
      'definition' => 'core/fontawesomeiconmapping',
      'sort' => 1,
    ),
    20 => 
    array (
      'store' => 'redis',
      'definition' => 'core/config',
      'sort' => 1,
    ),
    21 => 
    array (
      'store' => 'redis',
      'definition' => 'tool_mobile/plugininfo',
      'sort' => 1,
    ),
    22 => 
    array (
      'store' => 'redis',
      'definition' => 'core/plugin_functions',
      'sort' => 1,
    ),
    23 => 
    array (
      'store' => 'redis',
      'definition' => 'core/postprocessedcss',
      'sort' => 1,
    ),
    24 => 
    array (
      'store' => 'redis',
      'definition' => 'core/plugin_manager',
      'sort' => 1,
    ),
    25 => 
    array (
      'store' => 'redis',
      'definition' => 'tool_usertours/stepdata',
      'sort' => 1,
    ),
    26 => 
    array (
      'store' => 'redis',
      'definition' => 'availability_grade/items',
      'sort' => 1,
    ),
    27 => 
    array (
      'store' => 'local_file',
      'definition' => 'core/string',
      'sort' => 1,
    ),
    28 => 
    array (
      'store' => 'redis',
      'definition' => 'core/externalbadges',
      'sort' => 1,
    ),
    29 => 
    array (
      'store' => 'local_file',
      'definition' => 'core/langmenu',
      'sort' => 1,
    ),
    30 => 
    array (
      'store' => 'local_file',
      'definition' => 'core/htmlpurifier',
      'sort' => 1,
    ),
    31 => 
    array (
      'store' => 'redis',
      'definition' => 'core/completion',
      'sort' => 1,
    ),
    32 => 
    array (
      'store' => 'redis',
      'definition' => 'core/calendar_subscriptions',
      'sort' => 1,
    ),
    33 => 
    array (
      'store' => 'redis',
      'definition' => 'core/contextwithinsights',
      'sort' => 1,
    ),
    34 => 
    array (
      'store' => 'redis',
      'definition' => 'tool_monitor/eventsubscriptions',
      'sort' => 1,
    ),
    35 => 
    array (
      'store' => 'redis',
      'definition' => 'core/message_time_last_message_between_users',
      'sort' => 1,
    ),
    36 => 
    array (
      'store' => 'redis',
      'definition' => 'availability_grade/scores',
      'sort' => 1,
    ),
  ),
  'locks' => 
  array (
    'cachelock_file_default' => 
    array (
      'name' => 'cachelock_file_default',
      'type' => 'cachelock_file',
      'dir' => 'filelocks',
      'default' => true,
    ),
  ),
);
EOF
}

# Long fail2ban config command moved here
function config_fail2ban
{
    cat <<EOF > /etc/fail2ban/jail.conf
# Fail2Ban configuration file.
#
# This file was composed for Debian systems from the original one
# provided now under /usr/share/doc/fail2ban/examples/jail.conf
# for additional examples.
#
# Comments: use '#' for comment lines and ';' for inline comments
#
# To avoid merges during upgrades DO NOT MODIFY THIS FILE
# and rather provide your changes in /etc/fail2ban/jail.local
#

# The DEFAULT allows a global definition of the options. They can be overridden
# in each jail afterwards.

[DEFAULT]

# "ignoreip" can be an IP address, a CIDR mask or a DNS host. Fail2ban will not
# ban a host which matches an address in this list. Several addresses can be
# defined using space separator.
ignoreip = 127.0.0.1/8

# "bantime" is the number of seconds that a host is banned.
bantime  = 600

# A host is banned if it has generated "maxretry" during the last "findtime"
# seconds.
findtime = 600
maxretry = 3

# "backend" specifies the backend used to get files modification.
# Available options are "pyinotify", "gamin", "polling" and "auto".
# This option can be overridden in each jail as well.
#
# pyinotify: requires pyinotify (a file alteration monitor) to be installed.
#            If pyinotify is not installed, Fail2ban will use auto.
# gamin:     requires Gamin (a file alteration monitor) to be installed.
#            If Gamin is not installed, Fail2ban will use auto.
# polling:   uses a polling algorithm which does not require external libraries.
# auto:      will try to use the following backends, in order:
#            pyinotify, gamin, polling.
backend = auto

# "usedns" specifies if jails should trust hostnames in logs,
#   warn when reverse DNS lookups are performed, or ignore all hostnames in logs
#
# yes:   if a hostname is encountered, a reverse DNS lookup will be performed.
# warn:  if a hostname is encountered, a reverse DNS lookup will be performed,
#        but it will be logged as a warning.
# no:    if a hostname is encountered, will not be used for banning,
#        but it will be logged as info.
usedns = warn

#
# Destination email address used solely for the interpolations in
# jail.{conf,local} configuration files.
destemail = root@localhost

#
# Name of the sender for mta actions
sendername = Fail2Ban

#
# ACTIONS
#

# Default banning action (e.g. iptables, iptables-new,
# iptables-multiport, shorewall, etc) It is used to define
# action_* variables. Can be overridden globally or per
# section within jail.local file
banaction = iptables-multiport

# email action. Since 0.8.1 upstream fail2ban uses sendmail
# MTA for the mailing. Change mta configuration parameter to mail
# if you want to revert to conventional 'mail'.
mta = sendmail

# Default protocol
protocol = tcp

# Specify chain where jumps would need to be added in iptables-* actions
chain = INPUT

#
# Action shortcuts. To be used to define action parameter

# The simplest action to take: ban only
action_ = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]

# ban & send an e-mail with whois report to the destemail.
action_mw = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
              %(mta)s-whois[name=%(__name__)s, dest="%(destemail)s", protocol="%(protocol)s", chain="%(chain)s", sendername="%(sendername)s"]

# ban & send an e-mail with whois report and relevant log lines
# to the destemail.
action_mwl = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
               %(mta)s-whois-lines[name=%(__name__)s, dest="%(destemail)s", logpath=%(logpath)s, chain="%(chain)s", sendername="%(sendername)s"]

# Choose default action.  To change, just override value of 'action' with the
# interpolation to the chosen action shortcut (e.g.  action_mw, action_mwl, etc) in jail.local
# globally (section [DEFAULT]) or per specific section
action = %(action_)s

#
# JAILS
#

# Next jails corresponds to the standard configuration in Fail2ban 0.6 which
# was shipped in Debian. Enable any defined here jail by including
#
# [SECTION_NAME]
# enabled = true

#
# in /etc/fail2ban/jail.local.
#
# Optionally you may override any other parameter (e.g. banaction,
# action, port, logpath, etc) in that section within jail.local

[ssh]

enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 6

[dropbear]

enabled  = false
port     = ssh
filter   = dropbear
logpath  = /var/log/auth.log
maxretry = 6

# Generic filter for pam. Has to be used with action which bans all ports
# such as iptables-allports, shorewall
[pam-generic]

enabled  = false
# pam-generic filter can be customized to monitor specific subset of 'tty's
filter   = pam-generic
# port actually must be irrelevant but lets leave it all for some possible uses
port     = all
banaction = iptables-allports
port     = anyport
logpath  = /var/log/auth.log
maxretry = 6

[xinetd-fail]

enabled   = false
filter    = xinetd-fail
port      = all
banaction = iptables-multiport-log
logpath   = /var/log/daemon.log
maxretry  = 2


[ssh-ddos]

enabled  = false
port     = ssh
filter   = sshd-ddos
logpath  = /var/log/auth.log
maxretry = 6


# Here we use blackhole routes for not requiring any additional kernel support
# to store large volumes of banned IPs

[ssh-route]

enabled = false
filter = sshd
action = route
logpath = /var/log/sshd.log
maxretry = 6

# Here we use a combination of Netfilter/Iptables and IPsets
# for storing large volumes of banned IPs
#
# IPset comes in two versions. See ipset -V for which one to use
# requires the ipset package and kernel support.
[ssh-iptables-ipset4]

enabled  = false
port     = ssh
filter   = sshd
banaction = iptables-ipset-proto4
logpath  = /var/log/sshd.log
maxretry = 6

[ssh-iptables-ipset6]

enabled  = false
port     = ssh
filter   = sshd
banaction = iptables-ipset-proto6
logpath  = /var/log/sshd.log
maxretry = 6


#
# HTTP servers
#

[apache]

enabled  = false
port     = http,https
filter   = apache-auth
logpath  = /var/log/apache*/*error.log
maxretry = 6

# default action is now multiport, so apache-multiport jail was left
# for compatibility with previous (<0.7.6-2) releases
[apache-multiport]

enabled   = false
port      = http,https
filter    = apache-auth
logpath   = /var/log/apache*/*error.log
maxretry  = 6

[apache-noscript]

enabled  = false
port     = http,https
filter   = apache-noscript
logpath  = /var/log/apache*/*error.log
maxretry = 6

[apache-overflows]

enabled  = false
port     = http,https
filter   = apache-overflows
logpath  = /var/log/apache*/*error.log
maxretry = 2

# Ban attackers that try to use PHP's URL-fopen() functionality
# through GET/POST variables. - Experimental, with more than a year
# of usage in production environments.

[php-url-fopen]

enabled = false
port    = http,https
filter  = php-url-fopen
logpath = /var/www/*/logs/access_log

# A simple PHP-fastcgi jail which works with lighttpd.
# If you run a lighttpd server, then you probably will
# find these kinds of messages in your error_log:
#   ALERT – tried to register forbidden variable ‘GLOBALS’
#   through GET variables (attacker '1.2.3.4', file '/var/www/default/htdocs/index.php')

[lighttpd-fastcgi]

enabled = false
port    = http,https
filter  = lighttpd-fastcgi
logpath = /var/log/lighttpd/error.log

# Same as above for mod_auth
# It catches wrong authentifications

[lighttpd-auth]

enabled = false
port    = http,https
filter  = suhosin
logpath = /var/log/lighttpd/error.log

[nginx-http-auth]

enabled = false
filter  = nginx-http-auth
port    = http,https
logpath = /var/log/nginx/error.log

# Monitor roundcube server

[roundcube-auth]

enabled  = false
filter   = roundcube-auth
port     = http,https
logpath  = /var/log/roundcube/userlogins


[sogo-auth]

enabled  = false
filter   = sogo-auth
port     = http, https
# without proxy this would be:
# port    = 20000
logpath  = /var/log/sogo/sogo.log


#
# FTP servers
#

[vsftpd]

enabled  = false
port     = ftp,ftp-data,ftps,ftps-data
filter   = vsftpd
logpath  = /var/log/vsftpd.log
# or overwrite it in jails.local to be
# logpath = /var/log/auth.log
# if you want to rely on PAM failed login attempts
# vsftpd's failregex should match both of those formats
maxretry = 6


[proftpd]

enabled  = false
port     = ftp,ftp-data,ftps,ftps-data
filter   = proftpd
logpath  = /var/log/proftpd/proftpd.log
maxretry = 6


[pure-ftpd]

enabled  = false
port     = ftp,ftp-data,ftps,ftps-data
filter   = pure-ftpd
logpath  = /var/log/syslog
maxretry = 6


[wuftpd]

enabled  = false
port     = ftp,ftp-data,ftps,ftps-data
filter   = wuftpd
logpath  = /var/log/syslog
maxretry = 6


#
# Mail servers
#

[postfix]

enabled  = false
port     = smtp,ssmtp,submission
filter   = postfix
logpath  = /var/log/mail.log


[couriersmtp]

enabled  = false
port     = smtp,ssmtp,submission
filter   = couriersmtp
logpath  = /var/log/mail.log


#
# Mail servers authenticators: might be used for smtp,ftp,imap servers, so
# all relevant ports get banned
#

[courierauth]

enabled  = false
port     = smtp,ssmtp,submission,imap2,imap3,imaps,pop3,pop3s
filter   = courierlogin
logpath  = /var/log/mail.log


[sasl]

enabled  = false
port     = smtp,ssmtp,submission,imap2,imap3,imaps,pop3,pop3s
filter   = postfix-sasl
# You might consider monitoring /var/log/mail.warn instead if you are
# running postfix since it would provide the same log lines at the
# "warn" level but overall at the smaller filesize.
logpath  = /var/log/mail.log

[dovecot]

enabled = false
port    = smtp,ssmtp,submission,imap2,imap3,imaps,pop3,pop3s
filter  = dovecot
logpath = /var/log/mail.log

# To log wrong MySQL access attempts add to /etc/my.cnf:
# log-error=/var/log/mysqld.log
# log-warning = 2
[mysqld-auth]

enabled  = false
filter   = mysqld-auth
port     = 3306
logpath  = /var/log/mysqld.log


# DNS Servers


# These jails block attacks against named (bind9). By default, logging is off
# with bind9 installation. You will need something like this:
#
# logging {
#     channel security_file {
#         file "/var/log/named/security.log" versions 3 size 30m;
#         severity dynamic;
#         print-time yes;
#     };
#     category security {
#         security_file;
#     };
# };
#
# in your named.conf to provide proper logging

# !!! WARNING !!!
#   Since UDP is connection-less protocol, spoofing of IP and imitation
#   of illegal actions is way too simple.  Thus enabling of this filter
#   might provide an easy way for implementing a DoS against a chosen
#   victim. See
#    http://nion.modprobe.de/blog/archives/690-fail2ban-+-dns-fail.html
#   Please DO NOT USE this jail unless you know what you are doing.
#[named-refused-udp]
#
#enabled  = false
#port     = domain,953
#protocol = udp
#filter   = named-refused
#logpath  = /var/log/named/security.log

[named-refused-tcp]

enabled  = false
port     = domain,953
protocol = tcp
filter   = named-refused
logpath  = /var/log/named/security.log

# Multiple jails, 1 per protocol, are necessary ATM:
# see https://github.com/fail2ban/fail2ban/issues/37
[asterisk-tcp]

enabled  = false
filter   = asterisk
port     = 5060,5061
protocol = tcp
logpath  = /var/log/asterisk/messages

[asterisk-udp]

enabled  = false
filter	 = asterisk
port     = 5060,5061
protocol = udp
logpath  = /var/log/asterisk/messages


# Jail for more extended banning of persistent abusers
# !!! WARNING !!!
#   Make sure that your loglevel specified in fail2ban.conf/.local
#   is not at DEBUG level -- which might then cause fail2ban to fall into
#   an infinite loop constantly feeding itself with non-informative lines
[recidive]

enabled  = false
filter   = recidive
logpath  = /var/log/fail2ban.log
action   = iptables-allports[name=recidive]
           sendmail-whois-lines[name=recidive, logpath=/var/log/fail2ban.log]
bantime  = 604800  ; 1 week
findtime = 86400   ; 1 day
maxretry = 5
EOF
}

#
#
#
#
#
#
#
#
moodle_on_azure_configs_json_path="/var/lib/cloud/instance/moodle_on_azure_configs.json"

get_setup_params_from_configs_json $moodle_on_azure_configs_json_path || exit 99

echo $glusterNode    >> /tmp/vars.txt
echo $glusterVolume  >> /tmp/vars.txt
echo $siteFQDN >> /tmp/vars.txt
echo $httpsTermination >> /tmp/vars.txt
echo $syslogServer >> /tmp/vars.txt
echo $webServerType >> /tmp/vars.txt
echo $dbServerType >> /tmp/vars.txt
echo $fileServerType >> /tmp/vars.txt
echo $storageAccountName >> /tmp/vars.txt
echo $storageAccountKey >> /tmp/vars.txt
echo $nfsVmName >> /tmp/vars.txt
echo $nfsByoIpExportPath >> /tmp/vars.txt
echo $htmlLocalCopySwitch >> /tmp/vars.txt
echo $phpVersion          >> /tmp/vars.txt



check_fileServerType_param $fileServerType

{
  set -ex
  echo "### Function Start `date`###"

  # add azure-cli repository
  curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
  AZ_REPO=$(lsb_release -cs)
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |  tee /etc/apt/sources.list.d/azure-cli.list
  
  # add PHP-FPM repository 
  add-apt-repository ppa:ondrej/php -y > /dev/null 2>&1

  apt-get -qq -o=Dpkg::Use-Pty=0 update 

  # install pre-requisites including VARNISH and PHP-FPM
  export DEBIAN_FRONTEND=noninteractive
  apt-get --yes \
    --no-install-recommends \
    -qq -o=Dpkg::Use-Pty=0 \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    install \
    azure-cli \
    ca-certificates \
    curl \
    apt-transport-https \
    lsb-release gnupg \
    software-properties-common \
    unzip \
    rsyslog \
    postgresql-client \
    mysql-client \
    git \
    unattended-upgrades \
    tuned \
    varnish \
    php$phpVersion \
    php$phpVersion-cli \
    php$phpVersion-curl \
    php$phpVersion-zip \
    php-pear \
    php$phpVersion-mbstring \
    mcrypt \
    php$phpVersion-dev \
    graphviz \
    aspell \
    php$phpVersion-soap \
    php$phpVersion-json \
    php$phpVersion-redis \
    php$phpVersion-bcmath \
    php$phpVersion-gd \
    php$phpVersion-pgsql \
    php$phpVersion-mysql \
    php$phpVersion-xmlrpc \
    php$phpVersion-intl \
    php$phpVersion-xml \
    php$phpVersion-bz2

  # install azcopy
  wget -q -O azcopy_v10.tar.gz https://aka.ms/downloadazcopy-v10-linux && tar -xf azcopy_v10.tar.gz --strip-components=1 && mv ./azcopy /usr/bin/

  # kernel settings
  cat <<EOF > /etc/sysctl.d/99-network-performance.conf
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_wmem = 4096 12582912 16777216
net.ipv4.tcp_rmem = 4096 12582912 16777216
net.ipv4.route.flush = 1
net.ipv4.tcp_max_syn_backlog = 8096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 10240 65535
EOF
  # apply the new kernel settings
  sysctl -p /etc/sysctl.d/99-network-performance.conf

  # scheduling IRQ interrupts on the last two cores of the cpu
  # masking 0011 or 00000011 the result will always be 3 echo "obase=16;ibase=2;0011" | bc | tr '[:upper:]' '[:lower:]'
  if [ -f /etc/default/irqbalance ]; then
    sed -i "s/\#IRQBALANCE_BANNED_CPUS\=/IRQBALANCE_BANNED_CPUS\=3/g" /etc/default/irqbalance
    systemctl restart irqbalance.service 
  fi

  # configuring tuned for throughput-performance
  systemctl enable tuned
  tuned-adm profile throughput-performance

  if [ $fileServerType = "gluster" ]; then
    #configure gluster repository & install gluster client
    add-apt-repository ppa:gluster/glusterfs-3.10 -y
    apt-get -y update
    apt-get -y -qq -o=Dpkg::Use-Pty=0 install glusterfs-client
  elif [ "$fileServerType" = "azurefiles" ]; then
    apt-get -y -qq -o=Dpkg::Use-Pty=0 install cifs-utils
  fi

  if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ]; then
    apt-get --yes -qq -o=Dpkg::Use-Pty=0 install nginx
  fi
   
  if [ "$webServerType" = "apache" ]; then
    # install apache pacakges
    apt-get --yes -qq -o=Dpkg::Use-Pty=0 install apache2 libapache2-mod-php
  else
    # for nginx-only option
    apt-get --yes -qq -o=Dpkg::Use-Pty=0 install php$phpVersion-fpm
  fi
   
  # Moodle requirements
  if [ "$dbServerType" = "mssql" ]; then
    install_php_mssql_driver
  fi
   
  # PHP Version
  PhpVer=$(get_php_version)

  if [ $fileServerType = "gluster" ]; then
    # Mount gluster fs for /moodle
    sudo mkdir -p /moodle
    sudo chown www-data /moodle
    sudo chmod 770 /moodle
    sudo echo -e 'Adding Gluster FS to /etc/fstab and mounting it'
    setup_and_mount_gluster_moodle_share $glusterNode $glusterVolume
  elif [ $fileServerType = "nfs" ]; then
    # mount NFS export (set up on controller VM--No HA)
    echo -e '\n\rMounting NFS export from '$nfsVmName':/moodle on /moodle and adding it to /etc/fstab\n\r'
    configure_nfs_client_and_mount $nfsVmName /moodle /moodle
  elif [ $fileServerType = "nfs-ha" ]; then
    # mount NFS-HA export
    echo -e '\n\rMounting NFS export from '$nfsHaLbIP':'$nfsHaExportPath' on /moodle and adding it to /etc/fstab\n\r'
    configure_nfs_client_and_mount $nfsHaLbIP $nfsHaExportPath /moodle
  elif [ $fileServerType = "nfs-byo" ]; then
    # mount NFS-BYO export
    echo -e '\n\rMounting NFS export from '$nfsByoIpExportPath' on /moodle and adding it to /etc/fstab\n\r'
    configure_nfs_client_and_mount0 $nfsByoIpExportPath /moodle
  else # "azurefiles"
    setup_and_mount_azure_files_moodle_share $storageAccountName $storageAccountKey
  fi

  # Configure syslog to forward
  cat <<EOF >> /etc/rsyslog.conf
\$ModLoad imudp
\$UDPServerRun 514
EOF
  cat <<EOF >> /etc/rsyslog.d/40-remote.conf
local1.*   @${syslogServer}:514
local2.*   @${syslogServer}:514
EOF
  service syslog restart

  if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ]; then
    # Build nginx config
    cat <<EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
	worker_connections 8192;
  multi_accept on;
  use epoll;
}

worker_rlimit_nofile 100000;

http {

  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  client_max_body_size 0;
  proxy_max_temp_file_size 0;
  server_names_hash_bucket_size  128;
  fastcgi_buffers 16 16k; 
  fastcgi_buffer_size 32k;
  proxy_buffering off;
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  open_file_cache max=20000 inactive=20s;
  open_file_cache_valid 30s;
  open_file_cache_min_uses 2;
  open_file_cache_errors on;

  set_real_ip_from   127.0.0.1;
  real_ip_header      X-Forwarded-For;
  #upgrading to TLSv1.2 and droping 1 & 1.1
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers off;
  #adding ssl ciphers
  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

  gzip on;
  gzip_disable "msie6";
  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_buffers 16 8k;
  gzip_http_version 1.1;
  gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
EOF
    if [ "$httpsTermination" != "None" ]; then
      cat <<EOF >> /etc/nginx/nginx.conf
  map \$http_x_forwarded_proto \$fastcgi_https {                                                                                          
    default \$https;                                                                                                                   
    http '';                                                                                                                          
    https on;                                                                                                                         
  }
EOF
    fi

    cat <<EOF >> /etc/nginx/nginx.conf
  log_format moodle_combined '\$remote_addr - \$upstream_http_x_moodleuser [\$time_local] '
                             '"\$request" \$status \$body_bytes_sent '
                             '"\$http_referer" "\$http_user_agent"';


  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
}
EOF
  fi # if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ];

  # Set up html dir local copy if specified
  htmlRootDir="/moodle/html/moodle"
  if [ "$htmlLocalCopySwitch" = "true" ]; then
    if [ "$fileServerType" = "azurefiles" ]; then
      mkdir -p /var/www/html
      ACCOUNT_KEY="$storageAccountKey"
      NAME="$storageAccountName"
      END=`date -u -d "60 minutes" '+%Y-%m-%dT%H:%M:00Z'`
      htmlRootDir="/var/www/html/moodle"

      sas=$(az storage share generate-sas \
        -n moodle \
        --account-key $ACCOUNT_KEY \
        --account-name $NAME \
        --https-only \
        --permissions lr \
        --expiry $END -o tsv)

      export AZCOPY_CONCURRENCY_VALUE='48'
      export AZCOPY_BUFFER_GB='4'

      azcopy --log-level ERROR copy "https://$NAME.file.core.windows.net/moodle/html/moodle/*?$sas" $htmlRootDir --recursive
      chown www-data:www-data -R $htmlRootDir && sync
      setup_html_local_copy_cron_job
    fi
    if [ "$fileServerType" = "nfs" -o "$fileServerType" = "nfs-ha" -o "$fileServerType" = "nfs-byo" -o "$fileServerType" = "gluster" ]; then
      mkdir -p /var/www/html/moodle
      rsync -a /moodle/html/moodle/ $htmlRootDir/
      chown www-data:www-data -R $htmlRootDir && sync
      setup_html_local_copy_cron_job
    fi
  fi

  if [ "$httpsTermination" = "VMSS" ]; then
    # Configure nginx/https
    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
server {
        listen 443 ssl http2;
        root ${htmlRootDir};
	      index index.php index.html index.htm;

        ssl on;
        ssl_certificate /moodle/certs/nginx.crt;
        ssl_certificate_key /moodle/certs/nginx.key;
        ssl_session_timeout 1d;
        ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
        ssl_session_tickets off;

        # Log to syslog
        error_log syslog:server=localhost,facility=local1,severity=error,tag=moodle;
        access_log syslog:server=localhost,facility=local1,severity=notice,tag=moodle moodle_combined;

        # Log XFF IP instead of varnish
        set_real_ip_from    10.0.0.0/8;
        set_real_ip_from    127.0.0.1;
        set_real_ip_from    172.16.0.0/12;
        set_real_ip_from    192.168.0.0/16;
        real_ip_header      X-Forwarded-For;
        real_ip_recursive   on;

        location / {
          proxy_set_header Host \$host;
          proxy_set_header HTTP_REFERER \$http_referer;
          proxy_set_header X-Forwarded-Host \$host;
          proxy_set_header X-Forwarded-Server \$host;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_pass http://localhost:80;

          proxy_next_upstream error timeout http_502 http_504;
          proxy_connect_timeout       3600;
          proxy_send_timeout          3600;
          proxy_read_timeout          3600;
          send_timeout                3600;
        }
}

EOF
  fi

  if [ "$webServerType" = "nginx" ]; then
    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
server {
        listen 81 default;
        server_name ${siteFQDN};
        root ${htmlRootDir};
	index index.php index.html index.htm;

        # Log to syslog
        error_log syslog:server=localhost,facility=local1,severity=error,tag=moodle;
        access_log syslog:server=localhost,facility=local1,severity=notice,tag=moodle moodle_combined;

        # Log XFF IP instead of varnish
        set_real_ip_from    10.0.0.0/8;
        set_real_ip_from    127.0.0.1;
        set_real_ip_from    172.16.0.0/12;
        set_real_ip_from    192.168.0.0/16;
        real_ip_header      X-Forwarded-For;
        real_ip_recursive   on;
EOF
    if [ "$httpsTermination" != "None" ]; then
      cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
        # Redirect to https
        if (\$http_x_forwarded_proto != https) {
                return 301 https://\$server_name\$request_uri;
        }
        rewrite ^/(.*\.php)(/)(.*)$ /\$1?file=/\$3 last;
EOF
    fi
    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
        # Filter out php-fpm status page
        location ~ ^/server-status {
            return 404;
        }

	location / {
		try_files \$uri \$uri/index.php?\$query_string;
	}
 
        location ~ [^/]\.php(/|$) {
          fastcgi_split_path_info ^(.+?\.php)(/.*)$;
          if (!-f \$document_root\$fastcgi_script_name) {
                  return 404;
          }
 
          fastcgi_buffers 16 16k;
          fastcgi_buffer_size 32k;
          fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
          fastcgi_pass backend;
          fastcgi_param PATH_INFO \$fastcgi_path_info;
          fastcgi_read_timeout 3600;
          fastcgi_index index.php;
          include fastcgi_params;
        }
}

upstream backend {
        server unix:/run/php/php${PhpVer}-fpm.sock fail_timeout=1s;
        server unix:/run/php/php${PhpVer}-fpm-backup.sock backup;
}  

EOF
  fi

  if [ "$webServerType" = "apache" ]; then
    # Configure Apache/php
    sed -i "s/Listen 80/Listen 81/" /etc/apache2/ports.conf
    a2enmod rewrite && a2enmod remoteip && a2enmod headers

    cat <<EOF >> /etc/apache2/sites-enabled/${siteFQDN}.conf
<VirtualHost *:81>
	ServerName ${siteFQDN}

	ServerAdmin webmaster@localhost
	DocumentRoot ${htmlRootDir}

	<Directory ${htmlRootDir}>
		Options FollowSymLinks
		AllowOverride All
		Require all granted
	</Directory>
EOF
    if [ "$httpsTermination" != "None" ]; then
      cat <<EOF >> /etc/apache2/sites-enabled/${siteFQDN}.conf
    # Redirect unencrypted direct connections to HTTPS
    <IfModule mod_rewrite.c>
      RewriteEngine on
      RewriteCond %{HTTP:X-Forwarded-Proto} !https [NC]
      RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [L,R=301]
    </IFModule>
EOF
    fi
    cat <<EOF >> /etc/apache2/sites-enabled/${siteFQDN}.conf
    # Log X-Forwarded-For IP address instead of varnish (127.0.0.1)
    SetEnvIf X-Forwarded-For "^.*\..*\..*\..*" forwarded
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%{X-Forwarded-For}i %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" forwarded
	ErrorLog "|/usr/bin/logger -t moodle -p local1.error"
    CustomLog "|/usr/bin/logger -t moodle -p local1.notice" combined env=!forwarded
    CustomLog "|/usr/bin/logger -t moodle -p local1.notice" forwarded env=forwarded

</VirtualHost>
EOF
  fi # if [ "$webServerType" = "apache" ];

   # php config 
   if [ "$webServerType" = "apache" ]; then
     PhpIni=/etc/php/${PhpVer}/apache2/php.ini
   else
     PhpIni=/etc/php/${PhpVer}/fpm/php.ini
   fi
   sed -i "s/memory_limit.*/memory_limit = 512M/" $PhpIni
   sed -i "s/max_execution_time.*/max_execution_time = 18000/" $PhpIni
   sed -i "s/max_input_vars.*/max_input_vars = 100000/" $PhpIni
   sed -i "s/max_input_time.*/max_input_time = 600/" $PhpIni
   sed -i "s/upload_max_filesize.*/upload_max_filesize = 1024M/" $PhpIni
   sed -i "s/post_max_size.*/post_max_size = 1056M/" $PhpIni
   sed -i "s/;opcache.use_cwd.*/opcache.use_cwd = 1/" $PhpIni
   sed -i "s/;opcache.validate_timestamps.*/opcache.validate_timestamps = 1/" $PhpIni
   sed -i "s/;opcache.save_comments.*/opcache.save_comments = 1/" $PhpIni
   sed -i "s/;opcache.enable_file_override.*/opcache.enable_file_override = 0/" $PhpIni
   sed -i "s/;opcache.enable.*/opcache.enable = 1/" $PhpIni
   sed -i "s/;opcache.memory_consumption.*/opcache.memory_consumption = 512/" $PhpIni
   sed -i "s/;opcache.max_accelerated_files.*/opcache.max_accelerated_files = 20000/" $PhpIni
    
   # Remove the default site. Moodle is the only site we want
   rm -f /etc/nginx/sites-enabled/default
   if [ "$webServerType" = "apache" ]; then
     rm -f /etc/apache2/sites-enabled/000-default.conf
   fi

   if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ]; then
     # update startup script to wait for certificate in /moodle mount
     setup_moodle_mount_dependency_for_systemd_service nginx || exit 1
     # restart Nginx
     sudo service nginx restart 
   fi

   # Configure varnish startup for 18.04
   VARNISHSTART="ExecStart=\/usr\/sbin\/varnishd -j unix,user=vcache -F -a :80 -T localhost:6082 -f \/etc\/varnish\/moodle.vcl -S \/etc\/varnish\/secret -s malloc,4096m -p thread_pool_min=1000 -p thread_pool_max=4000 -p thread_pool_add_delay=0.1 -p timeout_linger=10 -p timeout_idle=30 -p send_timeout=1800 -p thread_pools=2 -p http_max_hdr=512 -p workspace_backend=512k"
   sed -i "s/^ExecStart.*/${VARNISHSTART}/" /lib/systemd/system/varnish.service

   # Configure varnish VCL for moodle
   cat <<EOF >> /etc/varnish/moodle.vcl
vcl 4.0;

import std;
import directors;
backend default {
    .host = "localhost";
    .port = "81";
    .first_byte_timeout = 3600s;
    .connect_timeout = 600s;
    .between_bytes_timeout = 600s;
}

sub vcl_recv {
    # Varnish does not support SPDY or HTTP/2.0 untill we upgrade to Varnish 5.0
    if (req.method == "PRI") {
        return (synth(405));
    }

    if (req.restarts == 0) {
      if (req.http.X-Forwarded-For) {
        set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
      } else {
        set req.http.X-Forwarded-For = client.ip;
      }
    }

    # Non-RFC2616 or CONNECT HTTP requests methods filtered. Pipe requests directly to backend
    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE") {
      return (pipe);
    }

    # Varnish don't mess with healthchecks
    if (req.url ~ "^/admin/tool/heartbeat" || req.url ~ "^/healthcheck.php")
    {
        return (pass);
    }

    # Pipe requests to backup.php straight to backend - prevents problem with progress bar long polling 503 problem
    # This is here because backup.php is POSTing to itself - Filter before !GET&&!HEAD
    if (req.url ~ "^/backup/backup.php")
    {
        return (pipe);
    }

    # Varnish only deals with GET and HEAD by default. If request method is not GET or HEAD, pass request to backend
    if (req.method != "GET" && req.method != "HEAD") {
      return (pass);
    }

    ### Rules for Moodle and Totara sites ###
    # Moodle doesn't require Cookie to serve following assets. Remove Cookie header from request, so it will be looked up.
    if ( req.url ~ "^/altlogin/.+/.+\.(png|jpg|jpeg|gif|css|js|webp)$" ||
         req.url ~ "^/pix/.+\.(png|jpg|jpeg|gif)$" ||
         req.url ~ "^/theme/font.php" ||
         req.url ~ "^/theme/image.php" ||
         req.url ~ "^/theme/javascript.php" ||
         req.url ~ "^/theme/jquery.php" ||
         req.url ~ "^/theme/styles.php" ||
         req.url ~ "^/theme/yui" ||
         req.url ~ "^/lib/javascript.php/-1/" ||
         req.url ~ "^/lib/requirejs.php/-1/"
        )
    {
        set req.http.X-Long-TTL = "86400";
        unset req.http.Cookie;
        return(hash);
    }

    # Perform lookup for selected assets that we know are static but Moodle still needs a Cookie
    if(  req.url ~ "^/theme/.+\.(png|jpg|jpeg|gif|css|js|webp)" ||
         req.url ~ "^/lib/.+\.(png|jpg|jpeg|gif|css|js|webp)" ||
         req.url ~ "^/pluginfile.php/[0-9]+/course/overviewfiles/.+\.(?i)(png|jpg)$"
      )
    {
         # Set internal temporary header, based on which we will do things in vcl_backend_response
         set req.http.X-Long-TTL = "86400";
         return (hash);
    }

    # Serve requests to SCORM checknet.txt from varnish. Have to remove get parameters. Response body always contains "1"
    if ( req.url ~ "^/lib/yui/build/moodle-core-checknet/assets/checknet.txt" )
    {
        set req.url = regsub(req.url, "(.*)\?.*", "\1");
        unset req.http.Cookie; # Will go to hash anyway at the end of vcl_recv
        set req.http.X-Long-TTL = "86400";
        return(hash);
    }

    # Requests containing "Cookie" or "Authorization" headers will not be cached
    if (req.http.Authorization || req.http.Cookie) {
        return (pass);
    }

    # Almost everything in Moodle correctly serves Cache-Control headers, if
    # needed, which varnish will honor, but there are some which don't. Rather
    # than explicitly finding them all and listing them here we just fail safe
    # and don't cache unknown urls that get this far.
    return (pass);
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    # 
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.

    # We know these assest are static, let's set TTL >0 and allow client caching
    if ( beresp.http.Cache-Control && bereq.http.X-Long-TTL && beresp.ttl < std.duration(bereq.http.X-Long-TTL + "s", 1s) && !beresp.http.WWW-Authenticate )
    { # If max-age < defined in X-Long-TTL header
        set beresp.http.X-Orig-Pragma = beresp.http.Pragma; unset beresp.http.Pragma;
        set beresp.http.X-Orig-Cache-Control = beresp.http.Cache-Control;
        set beresp.http.Cache-Control = "public, max-age="+bereq.http.X-Long-TTL+", no-transform";
        set beresp.ttl = std.duration(bereq.http.X-Long-TTL + "s", 1s);
        unset bereq.http.X-Long-TTL;
    }
    else if( !beresp.http.Cache-Control && bereq.http.X-Long-TTL && !beresp.http.WWW-Authenticate ) {
        set beresp.http.X-Orig-Pragma = beresp.http.Pragma; unset beresp.http.Pragma;
        set beresp.http.Cache-Control = "public, max-age="+bereq.http.X-Long-TTL+", no-transform";
        set beresp.ttl = std.duration(bereq.http.X-Long-TTL + "s", 1s);
        unset bereq.http.X-Long-TTL;
    }
    else { # Don't touch headers if max-age > defined in X-Long-TTL header
        unset bereq.http.X-Long-TTL;
    }

    # Here we set X-Trace header, prepending it to X-Trace header received from backend. Useful for troubleshooting
    if(beresp.http.x-trace && !beresp.was_304) {
        set beresp.http.X-Trace = regsub(server.identity, "^([^.]+),?.*$", "\1")+"->"+regsub(beresp.backend.name, "^(.+)\((?:[0-9]{1,3}\.){3}([0-9]{1,3})\)","\1(\2)")+"->"+beresp.http.X-Trace;
    }
    else {
        set beresp.http.X-Trace = regsub(server.identity, "^([^.]+),?.*$", "\1")+"->"+regsub(beresp.backend.name, "^(.+)\((?:[0-9]{1,3}\.){3}([0-9]{1,3})\)","\1(\2)");
    }

    # Gzip JS, CSS is done at the ngnix level doing it here dosen't respect the no buffer requsets
    # if (beresp.http.content-type ~ "application/javascript.*" || beresp.http.content-type ~ "text") {
    #    set beresp.do_gzip = true;
    #}
}

sub vcl_deliver {

    # Revert back to original Cache-Control header before delivery to client
    if (resp.http.X-Orig-Cache-Control)
    {
        set resp.http.Cache-Control = resp.http.X-Orig-Cache-Control;
        unset resp.http.X-Orig-Cache-Control;
    }

    # Revert back to original Pragma header before delivery to client
    if (resp.http.X-Orig-Pragma)
    {
        set resp.http.Pragma = resp.http.X-Orig-Pragma;
        unset resp.http.X-Orig-Pragma;
    }

    # (Optional) X-Cache HTTP header will be added to responce, indicating whether object was retrieved from backend, or served from cache
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }

    # Set X-AuthOK header when totara/varnsih authentication succeeded
    if (req.http.X-AuthOK) {
        set resp.http.X-AuthOK = req.http.X-AuthOK;
    }

    # If desired "Via: 1.1 Varnish-v4" response header can be removed from response
    unset resp.http.Via;
    unset resp.http.Server;

    return(deliver);
}

sub vcl_backend_error {
    # More comprehensive varnish error page. Display time, instance hostname, host header, url for easier troubleshooting.
    set beresp.http.Content-Type = "text/html; charset=utf-8";
    set beresp.http.Retry-After = "5";
    synthetic( {"
  <!DOCTYPE html>
  <html>
    <head>
      <title>"} + beresp.status + " " + beresp.reason + {"</title>
    </head>
    <body>
      <h1>Error "} + beresp.status + " " + beresp.reason + {"</h1>
      <p>"} + beresp.reason + {"</p>
      <h3>Guru Meditation:</h3>
      <p>Time: "} + now + {"</p>
      <p>Node: "} + server.hostname + {"</p>
      <p>Host: "} + bereq.http.host + {"</p>
      <p>URL: "} + bereq.url + {"</p>
      <p>XID: "} + bereq.xid + {"</p>
      <hr>
      <p>Varnish cache server
    </body>
  </html>
  "} );
   return (deliver);
}

sub vcl_synth {

    #Redirect using '301 - Permanent Redirect', permanent redirect
    if (resp.status == 851) { 
        set resp.http.Location = req.http.x-redir;
        set resp.http.X-Varnish-Redirect = true;
        set resp.status = 301;
        return (deliver);
    }

    #Redirect using '302 - Found', temporary redirect
    if (resp.status == 852) { 
        set resp.http.Location = req.http.x-redir;
        set resp.http.X-Varnish-Redirect = true;
        set resp.status = 302;
        return (deliver);
    }

    #Redirect using '307 - Temporary Redirect', !GET&&!HEAD requests, dont change method on redirected requests
    if (resp.status == 857) { 
        set resp.http.Location = req.http.x-redir;
        set resp.http.X-Varnish-Redirect = true;
        set resp.status = 307;
        return (deliver);
    }

    #Respond with 403 - Forbidden
    if (resp.status == 863) {
        set resp.http.X-Varnish-Error = true;
        set resp.status = 403;
        return (deliver);
    }
}
EOF

# This code is stop apache2 which is installing in 18.04
  service=apache2
  if [ "$webServerType" = "nginx" ]; then
      if pgrep -x "$service" >/dev/null 
      then
            echo “Stop the $service!!!”
            systemctl stop $service
      else
            systemctl mask $service
      fi
  fi
  # Restart Varnish
  systemctl daemon-reload
  systemctl restart varnish

   if [ "$webServerType" = "nginx" ]; then
     # fpm config - overload this 
     cat <<EOF > /etc/php/${PhpVer}/fpm/pool.d/www.conf
[www]
user = www-data
group = www-data
listen = /run/php/php${PhpVer}-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = static
pm.max_children = 32
pm.start_servers = 32
pm.max_requests = 300000
EOF

cat <<EOF > /etc/php/${PhpVer}/fpm/pool.d/backup.conf
[backup]
user = www-data
group = www-data
listen = /run/php/php${PhpVer}-fpm-backup.sock
listen.owner = www-data
listen.group = www-data
pm = static
pm.max_children = 16
pm.start_servers = 16
pm.max_requests = 300000
EOF

     # Restart fpm
     service php${PhpVer}-fpm restart
   fi

   if [ "$webServerType" = "apache" ]; then
      if [ "$htmlLocalCopySwitch" != "true" ]; then
        setup_moodle_mount_dependency_for_systemd_service apache2 || exit 1
      fi
        service apache2 restart
   fi

  echo "### Script End `date`###"
} 2>&1 | tee /tmp/setup.log