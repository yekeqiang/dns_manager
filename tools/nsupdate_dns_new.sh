#!/bin/bash

CALLER=`basename $0`

usage()
{


    echo "usage: ./${CALLER}  < -S servername (default is 127.0.0.1)> [ -Z zone_name (default is idc.test.com) ] [-D domain_name (default is 'test')] [-I domain_ip (default is 127.0.1)] [-O operators (default is add)] [-T ttl (default is 60)]"
    echo "    -S     servername   DNS 服务器的IP"
    echo "    -Z     zone_name    ZONE 的名称"
    echo "    -D     domain_name  需要解析的域名"
    echo "    -I     domain_ip    需要解析的域名的对应的IP"
    echo "    -O     operators    操作符，如 add, delete"
    echo "    -T     ttl          ttl 时间"
    echo "example:"
    echo "新增域名记录:"
    echo "     $ $0 -S 127.0.0.1 -Z idc.test.com -D bj-test-001 -I 127.0.0.1 -O add -T 60"
    echo "删除单个域名记录:"
    echo "     $ $0 -S 127.0.0.1 -Z idc.test.com -D bj-test-001 -I 127.0.0.1 -O del"
    echo "删除多个域名记录:"
    echo "     $ $0 -S 127.0.0.1 -Z idc.test.com -D bj-test-001 -I 127.0.0.1 -O delall"
    echo "修改域名记录:"
    echo "     $ $0 -S 127.0.0.1 -Z idc.test.com -D bj-test-001 -I 127.0.0.1 -O modify -T 60"

    exit 0
}


ARGS=`getopt -a -o S::Z:D:I:O:T::h -l servername:,zone_name:,domain_name:,domain_ip:,operators:,ttl:,help -- "$@"`

if [ $? != 0 ];then
    echo "${CALLER}: Unknown flag(s)" 
    usage
fi
#if [ $# -eq 0 ] || [ $# -lt 12 ] || [ $# -ge 13 ]
if [ $# -eq 0 ] || [ $# -ge 13 ]
then
    echo "你输入的命令行参数不符合规范，请按照提示处理！"
    usage
fi

# set 会重新排列参数的顺序，也就是改变$1,$2...$n的值，这些值在 getopt 中重新排列过了
eval set -- "$ARGS"

#经过 getopt 的处理，下面是处理具体选项
while true
do
        case "$1" in
        -S|--servername)
                servername="$2"
                shift
                ;;
        -Z|--zone_name)
                zone_name="$2"
                shift
                ;;
        -D|--domain_name)
                domain_name="$2"
                shift
                ;;
        -I|--domain_ip)
                domain_ip="$2"
                shift
                ;;
        -O|--operators)
                operators="$2"
                shift
                ;;
        -T|--ttl)
                ttl="$2"
                shift
                ;;
        -h|--help)
                usage
                ;;
        --)
                shift
                break
                ;;
        esac
shift
done

set_env()
{
    # type your parameters
    basedir="/var/named/chroot/etc"                  # named 的主目录
    keyfile_name="Kupdate.zones.key.+157+30577.key"
    keyfile="${basedir}"/"${keyfile_name}"           # 认证 key 的路径
    #ttl=600                                          # 指定的 ttl 的时间
    #zone_name="example.test.com"
    #domain_name="test19"
    hostname="${domain_name}"."${zone_name}"             # 涉及的 ZONE 的名称
    #servername="127.0.0.1"                           # DNS 服务器的IP
    #domain_ip="192.168.0.20"                         # 域名对应解析的 IP     
}

add_nsupdate()
{

    # create the temp file
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                    >  ${tmpfile}
    echo "zone ${zone_name}"                                                  >> ${tmpfile} 
    #要求domain-name中没有指定类别的资源记录
    echo "prereq nxrrset ${hostname} A"                                       >> ${tmpfile}
    echo "update add  ${hostname} ${ttl:=60} A ${domain_ip}"    >> ${tmpfile}
    echo "send"                                                               >> ${tmpfile}
}


del_nsupdate()
{
    # 删除某个域的单条记录
    # create the temp file
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    echo "zone ${zone_name}"                                                 >> ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${hostname} A"                                      >> ${tmpfile}
    echo "update delete  ${hostname} A ${domain_ip}"                  >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}



delall_nsupdate()
{
    # 删除某个域的全部全部记录
    # create the temp file
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    echo "zone ${zone_name}"                                                 >> ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${hostname} A"                                      >> ${tmpfile}
    echo "update delete  ${hostname} A"                               >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}

modify_nsupdate()
{
    #修改某条已经存在的记录，必须先删除，再新增
    #这有个问题，就是某域名存在多个记录的时候，而你只想修改多个中的其中一条映射关系，必须先全部全部，再弄，或者是先调用删除，再新增
    #
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    echo "zone ${zone_name}"                                                 >> ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${hostname} A"                                      >> ${tmpfile}
    echo "update delete  ${hostname} A "                                     >> ${tmpfile}
    echo "update add  ${hostname} ${ttl:=60} A ${domain_ip}"   >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}

execute_nsupdate()
{
    # send your IP to server
    nsupdate -k ${keyfile} -v ${tmpfile}
}

if [ "${operators}"x = "modify"x ];then
    set_env
    modify_nsupdate
    execute_nsupdate
elif [ "${operators}"x = "del"x ];then
    set_env
    del_nsupdate
    execute_nsupdate
elif [ "${operators}"x = "delall"x ];then
    set_env
    delall_nsupdate
    execute_nsupdate
else
    set_env
    add_nsupdate
    execute_nsupdate
fi