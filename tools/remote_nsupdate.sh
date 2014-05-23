#!/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH

# 0. keyin your parameters
basedir="/apps/sh/add_host_dns"                  # 基本工作目錄
keyfile="$basedir"/"Kupdate.zones.key.+157+30577.key"   # 將檔名填進去吧！
ttl=600                                    # 你可以指定 ttl 的時間喔！
outif="bond0"                               # 對外的連線介面！
zone_name="idc.vip.com"
hostname=`hostname`               # 你向 ISP 取得的那個主機名稱啦！
servername="10.201.52.245"               # 就是你的 ISP 啊！

# Get your new IP
newip=`/sbin/ifconfig "$outif" | grep 'inet addr' | \
        awk '{print $2}' | sed -e "s/addr\://"`
checkip=`echo $newip | grep "^[0-9]"`
if [ "$checkip" == "" ]; then
        echo "$0: The interface can't connect internet...."
        exit 1
fi

# create the temporal file
tmpfile=$basedir/tmp1.txt
cd $basedir
echo "server $servername"                       >  $tmpfile
echo "zone $zone_name "               >> $tmpfile
echo "update add    $hostname.$zone_name $ttl A $newip"    >> $tmpfile
echo "send"                                     >> $tmpfile

# send your IP to server
nsupdate -k $keyfile -v $tmpfile