#!/bin/bash
# 该工具是用来检查 zone 文件是否有问题。
# sh check_zone.sh example.test.com /var/named/chroot/etc/namedb/example.test.com
#
#
zone_name=$1
zone_file=$2
check_zone_command="sudo /usr/sbin/named-checkzone"
${check_zone_command} "${zone_name}" ${zone_file} > /dev/null 2>&1

if [ $? == 0 ];then
    echo "the zone file ${zone_file} is ok"
else
    echo "the zone file ${zone_file} is invalid"
fi