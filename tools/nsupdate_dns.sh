#!/bin/bash
# 该工具用来添加 zone 文件中的 A 记录
#
#
#
#

# type your parameters
basedir="/var/named/chroot/etc"                  # named 的主目录
keyfile_name="Kupdate.zones.key.+157+30577.key"
keyfile="${basedir}"/"${keyfile_name}"           # 认证 key 的路径
ttl=600                                          # 指定的 ttl 的时间
zone_name="example.vip.com"
domain_name="test19"
hostname="${domain_name}"."${zone_name}"             # 涉及的 ZONE 的名称
servername="127.0.0.1"                           # DNS 服务器的IP
domain_ip="192.168.0.20"                         # 域名对应解析的 IP     

# create the temp file
tmpfile=${basedir}/tmp.txt
cd ${basedir}
echo "server ${servername}"                             >  $tmpfile
echo "zone ${zone_name}"                                >> ${tmpfile} 
echo "update add  ${hostname} ${ttl} A ${domain_ip}"    >> $tmpfile
echo "send"                                             >> $tmpfile

# send your IP to server
nsupdate -k ${keyfile} -v ${tmpfile}