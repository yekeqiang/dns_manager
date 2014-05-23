#!/bin/bash
# A Bash shell script to create BIND ZONE FILE.
# Tested under BIND 8.x / 9.x, RHEL, DEBIAN, Fedora Linux.
# -------------------------------------------------------------------------
# Copyright (c) 2002,2009 Vivek Gite <vivek@nixcraft.com>
# This script is licensed under GNU GPL version 2.0 or above
# Examples:
# ./mkzone.sh example.com default-www-IP-address
# ./mkzone.sh cyberciti.biz 74.12.5.1
# -------------------------------------------------------------------------
# Last updated on: Mar//2014 - Fixed a few bugs.
# -------------------------------------------------------------------------
DOMAIN="$1"
WWWIP="$2"
 
if [ $# -le 1 ]
then
	echo "Syntax: $(basename $0) domainname www.domain.ip.address [profile]"
	echo "$(basename $0) example.com 1.2.3.4"
	exit 1
fi
 
# get profile
PROFILE="ns.profile.nixcraft.net"
[ "$3" != "" ] && PROFILE="$3"
 
SERIAL=$(date +"%Y%m%d")01                     # Serial yyyymmddnn
 
# load profile
source "$PROFILE"
 
# set default ns1
NS1=${NAMESERVERS[0]}
 
###### start SOA ######
echo "\$ORIGIN ${DOMAIN}."
echo "\$TTL ${TTL}"
echo "@	IN	SOA	${NS1}	${EMAILID}("
echo "			${SERIAL}	; Serial yyyymmddnn"
echo "			${REFRESH}		; Refresh After 3 hours"
echo "			${RETRY}		; Retry Retry after 1 hour"
echo "			${EXPIER}		; Expire after 1 week"
echo "			${MAXNEGTIVE})		; Minimum negative caching of 1 hour"
echo ""
 
###### start Name servers #######
# Get length of an array
tLen=${#NAMESERVERS[@]}
 
# use for loop read all nameservers
echo "; Name servers for $DOMAIN" 
for (( i=0; i<${tLen}; i++ ));
do
	echo "@			${ATTL}	IN	NS	${NAMESERVERS[$i]}"
done
 
###### start MX section #######
# get length of an array
tmLen=${#MAILSERVERS[@]}
 
# use for loop read all mailservers 
echo "; MX Records" 
for (( i=0; i<${tmLen}; i++ ));
do
	echo "@			${ATTL}	IN 	MX	$(( 10*${i} + 10 ))	${MAILSERVERS[$i]}"
done
 
 
###### start A pointers #######
# A Records - Default IP for domain 
echo '; A Records'
echo "@ 			${ATTL}	IN 	A	${WWWIP}"
 
# Default Nameserver IPs
# get length of an array
ttLen=${#NAMESERVERSIP[@]}
 
# make sure both nameserver and their IP match
if [ $tLen -eq $ttLen ]
then
# use for loop read all nameservers IPs
for (( i=0; i<${ttLen}; i++ ));
do
  	thisNs="$(echo ${NAMESERVERS[$i]} | cut -d'.' -f1)"
 
	echo "${thisNs} 			${ATTL}	IN	A	${NAMESERVERSIP[$i]}"
done
else
	# if we are here means, our nameserver IPs are defined else where else...  do nothing
	:
fi
 
echo "; CNAME Records"
echo "www			${ATTL}	IN	CNAME	@"
 
LoadCutomeARecords