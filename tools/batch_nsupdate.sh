#!/bin/bash
dns_domain_ip="/var/named/chroot/etc/batch.txt"
operators=$1
for i in `cat ${dns_domain_ip}`
do
  domain=`echo $i  |awk -F":" '{print $1}'`
  ip=`echo $i |awk -F":" '{print $2}'`
  sudo  ./nsupdate_dns.sh -S127.0.0.1  -D ${domain} -I ${ip} -O ${operators} -T300 -Htrue
done