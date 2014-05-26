#!/bin/bash
# this function is use to add domain to dns by nsupdate
# write by keqiang.ye
# email: yekeqiang@gmail.com 
#
#



CALLER=`basename $0`

usage()
{


    echo "usage: ./${CALLER}  < -S servername (default is 127.0.0.1)> [ -Z zone_name ] [-D domain_name)] [-I domain_ip ] [-O operators] [-T ttl (default is 60)]  [-H ishost (default is false)]"
    echo "    -S     servername   DNS 服务器的IP"
    echo "    -Z     zone_name    ZONE 的名称"
    echo "    -D     domain_name  需要解析的域名"
    echo "    -I     domain_ip    需要解析的域名的对应的IP"
    echo "    -O     operators    操作符，如 add, delete"
    echo "    -T     ttl          ttl 时间"
    echo "    -H     ishost       判断是否给服务器添加主机名映射，值为 true 即是给主机名映射，false 即域名映射"
    echo "example:"
    echo "新增域名记录:"
    echo "     $ $0 -S 127.0.0.1 -Z idc.example.com -D test.com -I 127.0.0.1 -O add -T 60"
    echo "删除单个域名记录:"
    echo "     $ $0 -S 127.0.0.1 -Z idc.example.com -D test.com -I 127.0.0.1 -O del"
    echo "删除多个域名记录:"
    echo "     $ $0 -S 127.0.0.1 -Z idc.example.com -D test.com -I 127.0.0.1 -O delall"
    echo "修改域名记录:"
    echo "     $ $0 -S 127.0.0.1 -Z idc.example.com -D test.com -I 127.0.0.1 -O modify -T 60"
    echo "添加主机名解析记录:"
    echo "     $ $0 -S 127.0.0.1 -Z idc.example.com -D test.com -I 127.0.0.1 -O modify -T 60 ishost=true"

    exit 0
}


ARGS=`getopt -a -o S::Z:D:I:O:T::H::h -l servername:,zone_name:,domain_name:,domain_ip:,operators:,ttl:,ishost:,help -- "$@"`


if [ $? != 0 ];then
    echo "${CALLER}: Unknown flag(s)" 
    usage
fi

if [ $# -eq 0 ] || [ $# -ge 15 ]
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

# 设置基本的环境变量
set_env()
{
    # type your parameters
    basedir="/var/named/chroot/etc"                  # named 的主目录
    keyfile_name="Kupdate.zones.key.+157+30577.key"
    keyfile="${basedir}"/"${keyfile_name}"           # 认证 key 的路径
    #ttl=600                                          # 指定的 ttl 的时间
    #zone_name="example.vip.com"
    #domain_name="test19"
    hostname="${domain_name}"."${zone_name}"             # 涉及的 ZONE 的名称
    #servername="127.0.0.1"                           # DNS 服务器的IP
    #domain_ip="192.168.0.20"                         # 域名对应解析的 IP     
}


# 新增 zone 中主机名 A 记录
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


# 新增 zone 中的域名 A 记录
add_domain_nsupdate()
{

    # create the temp file
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                    >  ${tmpfile}
    echo "zone ${zone_name}"                                                  >> ${tmpfile}
    echo "update add  ${hostname} ${ttl:=60} A ${domain_ip}"    >> ${tmpfile}
    echo "send"                                                               >> ${tmpfile}
}

# 删除 zone 中的 A 记录（单个）
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


# 删除 zone 中某个域名的全部 A 记录
# 比如一个域名对应多个IP
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

# 修改 zone 中的 A 记录
# 因为 nsupdate 不能直接修改，因此先删除指定的，然后再修改
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

# 执行 nsupdate 的命令
execute_nsupdate()
{
    # send your IP to server
    nsupdate -k ${keyfile} -v ${tmpfile}
}
#
# check_domain_ip 用来对输入的域名或者是IP做校验，看是否在 dns 中生效
# 这个检查有 BUG ，只能是应对 一对一的情况，一对多的话，在 -z 那会报错
check_domain_ip()
{
    # Make sure a paramater was passed

    # Do some regex to see if it's an IP or Hostname
    if [ $(echo $domain_name | egrep -o '^[0-9]+.[0-9]+.[0-9]+.[0-9]+') ]
    then
        # Its an IP, domain_name the PTR record
        records=$(nslookup $domain_name | grep 'name = ' | awk -F' = ' '{print $2}' | sed 's/.$//g' | sort)
    else
        # Its a hostname, domain_name the A record
        records=$(nslookup $domain_name | grep -A1 'Name:' | grep Address | awk -F': ' '{print $2}')
    fi
    # Were there any records returned?
    for record in $records
    do
        if [ -z $record ]
        then
            echo "the $domain_name is not exist or be deleted successful"
            exit 1

        else
            echo "$record"
     #       exit 0
        fi
    done
    exit 0
}



if [ "${operators}"x = "modify"x ];then
    set_env
    modify_nsupdate
    execute_nsupdate
    check_domain_ip
elif [ "${operators}"x = "del"x ];then
    set_env
    del_nsupdate
    execute_nsupdate
    check_domain_ip
elif [ "${operators}"x = "delall"x ];then
    set_env
    delall_nsupdate
    execute_nsupdate
    check_domain_ip
else
    if [ ! ${ishost:=false} ];then
         
         set_env
         add_nsupdate
         execute_nsupdate
         check_domain_ip
     else
         set_env
         add_domain_nsupdate
         execute_nsupdate
         check_domain_ip
     fi
fi