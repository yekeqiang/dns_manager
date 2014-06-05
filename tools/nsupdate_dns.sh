#!/bin/bash

CALLER=`basename $0`

usage()
{


    echo "usage: ./${CALLER}  < -S servername (default is 127.0.0.1)> [-D domain_name)] [-I domain_ip ] [-O operators] [-T ttl (def
ault is 300)]  [-H ishost (default is false)]"
    echo "    -S     servername   DNS 服务器的IP"
    echo "    -D     domain_name  需要解析的域名"
    echo "    -I     domain_ip    需要解析的域名的对应的IP"
    echo "    -O     operators    操作符，如 add, delete"
    echo "    -T     ttl          ttl 时间"
    echo "    -H     ishost       判断是否给服务器添加主机名映射，值为 true 即是给主机名映射，false 即域名映射"
    echo "说明:"
    echo "使用了 getopt 可选选项，即参数后面是双冒号'::'的话，参数和选项之间不能够有空格，必须紧挨着 "
    echo "使用了 modify 选项进行域名记录修改的时候，只能修改域名对应的 IP, 不能修改 IP 对应的域名，修改 IP 对应的域名会报错"
    echo "example:"
    echo "新增域名记录:"
    echo "     $ $0 -S127.0.0.1  -D bj-test-001 -I 127.0.0.1 -O add -T300"
    echo "删除单个域名记录:"
    echo "     $ $0 -S127.0.0.1  -D bj-test-001 -I 127.0.0.1 -O del"
    echo "删除多个域名记录:"
    echo "     $ $0 -S127.0.0.1  -D bj-test-001 -I 127.0.0.1 -O delall" 
    echo "修改域名记录:"
    echo "     $ $0 -S127.0.0.1  -D bj-test-001 -I 127.0.0.1 -O modify -T300"
    echo "添加主机名解析记录:"
    echo "     $ $0 -S127.0.0.1  -D bj-test-001 -I 127.0.0.1 -O add -T300 -Htrue"
    echo "修改主机名解析记录:"
    echo "     $ $0 -S127.0.0.1  -D bj-test-001 -I 127.0.0.1 -O modify -T300 -Htrue"
    echo "删除单个主机名记录:"
    echo "     $ $0 -S127.0.0.1  -D bj-test-001 -I 127.0.0.1 -O del -Htrue"

    exit 0
}


ARGS=`getopt -a -o S::D:I:O:T::H::h -l servername:,domain_name:,domain_ip:,operators:,ttl:,ishost:,help -- "$@"`
#ARGS=`getopt -a -o S::Z:D:I:O:T::h -l servername:,zone_name:,domain_name:,domain_ip:,operators:,ttl:,help -- "$@"`

if [ $? != 0 ];then
    echo "${CALLER}: Unknown flag(s)" 
    usage
fi

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
        -H|--ishost)
                ishost="$2"
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
    zonedir="${basedir}"/"namedb"                       # zone文件目录
    baselogdir="$basedir"/"log"                     # 日志目录
    modify_log="${baselogdir}"/"modify_record.log"
    remove_log="${baselogdir}"/"remove_record.log"
    add_log="${baselogdir}"/"add_record.log"
    keyfile_name="Kupdate.zones.key.+157+30577.key"
    keyfile="${basedir}"/"${keyfile_name}"           # 认证 key 的路径
    #ttl=3000                                          # 指定的 ttl 的时间
    #zone_name="example.vip.com"
    #domain_name="test19"
    #hostname="${domain_name}"."${zone_name}"             # 涉及的 ZONE 的名称
    host_zone="idc.vip.com"
    hostname="${domain_name}"             # 涉及的 ZONE 的名称
    #servername="127.0.0.1"                           # DNS 服务器的IP
    #domain_ip="192.168.0.20"                         # 域名对应解析的 IP     
    if [ ${ishost:=false} == true ];then
        host_zone="idc.vip.com"
    else
        host_zone=`echo ${domain_name} |awk -F"." '{print $2"."$3"."$4}'`
    fi
    ptr_zone=`echo ${domain_ip} |awk -F"." '{print $3"."$2"."$1".in-addr.arpa"}'`
    ptr_domain_ip=`echo ${domain_ip} |awk -F"." '{print $4"."$3"."$2"."$1".in-addr.arpa"}'`
}

# nsupdate 的共同基础操作
base_operation()
{
    # create the temp file
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                    >  ${tmpfile}

}

# 新增主机名正解记录
add_forward_host_nsupdate()
{

    # create the temp file
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                    >  ${tmpfile}
    #要求domain-name中没有指定类别的资源记录
    echo "prereq nxrrset ${hostname}.${host_zone} A"                                       >> ${tmpfile}
    echo "update add  ${hostname}.${host_zone} ${ttl:=300} A ${domain_ip}"    >> ${tmpfile}
    echo "send"                                                               >> ${tmpfile}
}

# 新增主机名反解记录
add_reverse_host_nsupdate()
{

    # create the temp file
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                    >  ${tmpfile}
    #要求domain-name中没有指定类别的资源记录
    echo "prereq nxrrset ${ptr_domain_ip} ptr"                                      >> ${tmpfile}
    echo "update add  ${ptr_domain_ip} ${ttl:=300} ptr ${domain_name}"    >> ${tmpfile}
    echo "send"           >> ${tmpfile}                                                    >> ${tmpfile}
}



# 新增域名的正解记录
add_forward_domain_nsupdate()
{

    # create the temp file
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                    >  ${tmpfile}
    echo "update add  ${hostname} ${ttl:=300} A ${domain_ip}"    >> ${tmpfile}
    echo "send"                                                               >> ${tmpfile}
}

# 新增域名的反解记录
add_reverse_domain_nsupdate()
{

    # create the temp file
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                    >  ${tmpfile}
    echo "update add  ${ptr_domain_ip} ${ttl:=300} ptr ${domain_name}"    >> ${tmpfile}
    echo "send"                                                               >> ${tmpfile}
}


# 删除域名 zone 中的 A 记录（单个）
# 删除正解记录
del_forward_domain_nsupdate()
{
    # 删除某个域的单条记录
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${hostname} A"                                      >> ${tmpfile}
    echo "update delete  ${hostname} A ${domain_ip}"                  >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}

# 删除域名 zone 中的 A 记录（单个）
# 删除反解记录
del_reverse_domain_nsupdate()
{
    # 删除某个域的单条记录
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${ptr_domain_ip} ptr"                                      >> ${tmpfile}
    echo "update delete  ${ptr_domain_ip} ptr ${domain_name}"    >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}

# 删除主机 zone 中的 A 记录（单个）
# 删除正解记录
del_forward_host_nsupdate()
{
    # 删除某个域的单条记录
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${hostname}.${host_zone} A"                                      >> ${tmpfile}
    echo "update delete  ${hostname}.${host_zone} A ${domain_ip}"                  >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}

# 删除主机 zone 中的 A 记录（单个）
# 删除反解记录
del_reverse_host_nsupdate()
{
    # 删除某个域的单条记录
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${ptr_domain_ip} ptr"                                      >> ${tmpfile}
    echo "update delete  ${ptr_domain_ip} ptr ${domain_name}"    >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}


# 删除 zone 中某个域名的全部 A 记录
# 比如一个域名对应多个IP
# 删除正解记录
delall_forward_domain_nsupdate()
{
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${hostname} A"                                      >> ${tmpfile}
    echo "update delete  ${hostname} A"                               >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}

# 删除 zone 中某个域名的全部 A 记录
# 比如一个域名对应多个IP
# 删除反解记录
delall_reverse_domain_nsupdate()
{
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${ptr_domain_ip} ptr"                                      >> ${tmpfile}
    echo "update delete  ${ptr_domain_ip}"    >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}



# 修改 zone 中的 A 记录
# 因为 nsupdate 不能直接修改，因此先删除指定的，然后再修改
# 修改正解记录
modify_forward_domain_nsupdate()
{
    #修改某条已经存在的记录，必须先删除，再新增
    #这有个问题，就是某域名存在多个记录的时候，而你只想修改多个中的其中一条映射关系，必须先全部全部，再弄，或者是先调用删除，再新增
    #修改域名的dns记录
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${hostname} A"                                      >> ${tmpfile}
    echo "update delete  ${hostname} A "                                     >> ${tmpfile}
    echo "update add  ${hostname} ${ttl:=300} A ${domain_ip}"   >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}



# 修改 zone 中的 A 记录
# 因为 nsupdate 不能直接修改，因此先删除指定的，然后再修改
# 修改反解记录
modify_reverse_domain_nsupdate()
{
    #修改某条已经存在的记录，必须先删除，再新增
    #这有个问题，就是某域名存在多个记录的时候，而你只想修改多个中的其中一条映射关系，必须先全部全部，再弄，或者是先调用删除，再新增
    #修改域名的dns记录
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq nxrrset ${ptr_domain_ip} ptr"                                      >> ${tmpfile}
    echo "update delete  ${ptr_domain_ip}"    >> ${tmpfile}
    echo "send"               >> ${tmpfile}
    echo "update add  ${ptr_domain_ip} ${ttl:=300} ptr ${domain_name}"    >> ${tmpfile}
    echo "send"               >> ${tmpfile}
}

# 修改主机名的的dns记录
# 正解记录
modify_forward_host_nsupdate()
{
    # 修改主机名的DNS记录
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${hostname}.${host_zone} A"                                      >> ${tmpfile}
    echo "update delete  ${hostname}.${host_zone} A "                                     >> ${tmpfile}
    echo "update add  ${hostname}.${host_zone} ${ttl:=300} A ${domain_ip}"   >> ${tmpfile}
    echo "send"                                                              >> ${tmpfile}
}


# 反解记录
# 修改反解记录，需要先找出原先的IP指向，然后在把原先的IP指向删除,但是目前传递进来的 ptr_domain_ip 是新的，因此不会出现删除的现象，
#需要处理下
#要先修改反解
modify_reverse_host_nsupdate()
{
    # 修改主机名的DNS记录
    record=$(nslookup ${hostname} | grep -A1 'Name:' | grep Address | awk -F': ' '{print $2}')
    ptr_old_domain_ip=`echo ${record} |awk -F"." '{print $4"."$3"."$2"."$1".in-addr.arpa"}'`
    tmpfile=${basedir}/tmp.txt
    cd ${basedir}
    echo "server ${servername:=127.0.0.1}"                                              >  ${tmpfile}
    #要求不存在一条指定的资源记录.类别和hostname必须存在
    echo "prereq yxrrset ${ptr_old_domain_ip} ptr"                                      >> ${tmpfile}
    echo "update delete  ${ptr_old_domain_ip}"    >> ${tmpfile}
    echo "send"               >> ${tmpfile}
    echo "prereq nxrrset ${ptr_domain_ip} ptr"                                      >> ${tmpfile}
    echo "update add  ${ptr_domain_ip} ${ttl:=300} ptr ${domain_name}"    >> ${tmpfile}
    echo "send"               >> ${tmpfile}
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
    # get the domain record to nslookup ip
    domain_records=$(nslookup ${domain_ip} | grep 'name = ' | awk -F' = ' '{print $2}' | sed 's/.$//g' | sort)
    # get the ip record  to nslookup domain
    ip_records=$(nslookup ${domain_name} | grep -A1 'Name:' | grep Address | awk -F': ' '{print $2}')
    # Were there any domain records returned in dns?
    for domain_record in ${domain_records}
    do
        if [ -z ${domain_record} ];then
            echo "the ${domain_ip} is not exist or be deleted successful"
        else
            echo "${domain_record}"
        fi
    done
    # were there any ip records returned in dns?
    for ip_record in ${ip_records}
    do
        if [ -z ${ip_record} ];then
            echo "the ${domain_name} is not exist or be deleted successful"
        else
            echo "${ip_record}"
        fi
    done

    if [ -z ${domain_record} ] && [ -z ${ip_record} ];then
        #echo "you can add ${domain_name} and  ${domain_ip} into zone file"
        return 0
    else
        if [ x${domain_record} == x${domain_name} -o x${ip_record} == x${domain_ip} ];then
            echo "the ${domain_name} and ${domain_ip}  name-value pair consistent match the ${domain_record} and ${ip_record} record"
            return 1
        else 
            if [ -z ${domain_record} ];then
                echo "the domain ${domain_name} is exist in dns system,the mapping ip record is ${ip_record}, please type correct domain name!"
                return 1
            else
                echo "the ip ${domain_ip} is exist in dns system,the mapping domain record is ${domain_record}, please type correct domain ip!"
                return 1
            fi
        fi
    fi
}

# 添加域名的时候，校验域名对应的 IP 是否已经存在，如果存在，则不能进行添加，
# 因为不能 一个 IP 对应多个域名
check_ip_isexist()
{
    domain_records=$(nslookup ${domain_ip} | grep 'name = ' | awk -F' = ' '{print $2}' | sed 's/.$//g' | sort)
    for domain_record in ${domain_records}
    do
        if [ -z ${domain_record} ];then
            return 0
        else
            return 1
        fi
    done
}

# 检查生产的 zone 文件中是否存在记录
check_isexist_domain_ip()
{
   set_env
   forword_record=`grep -Eai ${domain_name} ${zonedir}/*  --exclude=*.jnl`
   reverse_record=`grep -Eai ${domain_ip} ${zonedir}/*  --exclude=*.jnl`
   if [ -z "${forword_record}" ] || [ -z "${reverse_record}" ];then
       return 1
   else
       return 0
   fi
}


exexcute_forward_modify_host_dns()
{
    modify_forward_host_nsupdate
    execute_nsupdate
}

exexcute_reverse_modify_host_dns()
{
    modify_reverse_host_nsupdate
    execute_nsupdate
}

exexcute_forward_modify_domain_dns()
{
    modify_forward_domain_nsupdate
    execute_nsupdate
}

exexcute_reverse_modify_domain_dns()
{
    modify_reverse_domain_nsupdate
    execute_nsupdate
}


exexcute_forward_del_host_dns()
{
    del_forward_host_nsupdate
    execute_nsupdate
}

exexcute_reverse_del_host_dns()
{
    del_reverse_host_nsupdate
    execute_nsupdate
}

exexcute_forward_del_domain_dns()
{
    del_forward_domain_nsupdate
    execute_nsupdate
}

exexcute_reverse_del_domain_dns()
{
    del_reverse_domain_nsupdate
    execute_nsupdate
}


exexcute_forward_delall_domain_dns()
{
    delall_forward_domain_nsupdate
    execute_nsupdate
}

exexcute_reverse_delall_domain_dns()
{
    delall_reverse_domain_nsupdate
    execute_nsupdate
}

exexcute_forward_add_domain_dns()
{
    add_forward_domain_nsupdate
    execute_nsupdate
}

exexcute_reverse_add_domain_dns()
{
    add_reverse_domain_nsupdate
    execute_nsupdate
}

exexcute_forward_add_host_dns()
{
    add_forward_host_nsupdate
    execute_nsupdate
}


exexcute_reverse_add_host_dns()
{
    add_reverse_host_nsupdate
    execute_nsupdate
}

#设置环境变量
set_env

if [ "${operators}"x = "modify"x ];then
    # 对是添加的主机名还是域名做判断，当为 true 时即是添加主机名，当为 false 时是添加的域名
    if [ ${ishost:=false} == true ];then
        exexcute_reverse_modify_host_dns
        echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},forward,${host_zone}" >> ${add_log}
        exexcute_forward_modify_host_dns
        echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},reverse,${ptr_zone}" >> ${add_log}
    else
        exexcute_reverse_modify_domain_dns
        echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},forward,${host_zone}" >> ${add_log}
        exexcute_forward_modify_domain_dns
        echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},reverse,${ptr_zone}" >> ${add_log}
    fi
elif [ "${operators}"x = "del"x ];then
    if [ ${ishost:=false} == true ];then
        check_domain_ip
        if [ $? -eq 0 ];then
            echo "the ${domain_name} and ${domain_ip} is not exist, you can't delete, please type already exists domain and ip!"
            exit 1
        else
            exexcute_forward_del_host_dns
            echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},forward,${host_zone}" >> ${add_log}
            exexcute_reverse_del_host_dns
            echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},reverse,${ptr_zone}" >> ${add_log}
        fi
    else
        exexcute_forward_del_domain_dns    
        echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},forward,${host_zone}" >> ${add_log}
        exexcute_reverse_del_domain_dns    
        echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},reverse,${ptr_zone}" >> ${add_log}
    fi
elif [ "${operators}"x = "delall"x ];then
        exexcute_forward_delall_domain_dns
        echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},forward,${host_zone}" >> ${add_log}
        exexcute_reverse_delall_domain_dns
        echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},reverse,${ptr_zone}" >> ${add_log}
else
    if [ ${ishost:=false} == true ];then
        check_isexist_domain_ip
        if [ $? -gt 0 ];then
            check_domain_ip
            if [ $? -eq 0 ];then
                exexcute_forward_add_host_dns
                echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},forward,${host_zone}" >> ${add_log}
                exexcute_reverse_add_host_dns
                echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},reverse,${ptr_zone}" >> ${add_log}
            else
                echo "add ${domain_name} and ${domain_ip} fail, please type correct domain and ip"
                exit 1                
            fi
        else
            echo "the ${domain_name} or ${domain_ip} maybe exist, please type correct domain or ip"
            exit 1
        fi
    else
        check_ip_isexist
        if [ $? -eq 0 ];then
            exexcute_forward_add_domain_dns
            echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},forward,${host_zone}" >> ${add_log}
            exexcute_reverse_add_domain_dns
            echo "`date +"%Y-%m-%d %H:%M:%S"`,${operators},${domain_name},${domain_ip},reverse,${ptr_zone}" >> ${add_log}
        else
            echo "the ${domain_ip} is exist in dns system, the match domain record is ${domain_record}, you can't add!"
            exit 1
        fi
    fi
fi