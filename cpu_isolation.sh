#!/bin/bash

#此脚本用于设置cpu隔离;

ISO_CPU_LIST=""

usage(){
    echo "===================================================================================="
    echo "使用说明："
    echo "    sh ./cpu_isolation.sh help                 //显示帮助信息"
    echo "    sh ./cpu_isolation.sh show                 //查看当前grub配置信息/当前生效信息/cpu信息"
    echo "    sh ./cpu_isolation.sh bind cpu1,cpu2,...   //隔离指定cpu用于dpdk,多个cpu用逗号分隔"
    echo "    sh ./cpu_isolation.sh reset                //删除隔离的cpu配置"
    echo "使用步骤："
    echo "    1. 查看adns/adns.conf-->nic-->piplinex-->取第二个括号中的cpu号(目前只需绑定forwarder线程)"
    echo "    2. 运行本脚本show命令，获取第一步中得到cpu的sibling cpu号(对于开启超线程的系统适用，其他则跳过)"
    echo "    3. 运行本脚本bind命令，入参为第一步和第二步得到的所有cpu号，逗号隔开"
    echo "    4. 重启物理机 reboot"
    echo "    5. 查看绑定是否生效 ps -eLo ruser,pid,ppid,lwp,psr,args | awk '{if(\$5==19) print \$0}' "
    echo "       其中：19为绑定的cpu号，如果输出只有内核相关线程kworker/migration，没有用户进程，则说明成功"
    echo "===================================================================================="
}

check_cpu_list(){
    if [[ $1 =~ ^[0-9,\-]+$ ]];then
        echo "CPU ISOLATION LIST[$1] format OK."
        return 0
    else
        echo "CPU ISOLATION LIST[$1] format ERROR."
        return 1
    fi
}

grub_rebuild(){
    grub2-mkconfig -o /boot/grub2/grub.cfg
    if [ $? -eq 0 ] 
    then
        echo "$(date): INFO: grup重建成功，请重启服务生效!"
        echo "$(date): INFO: now conf is: $(grep GRUB_CMDLINE_LINUX /etc/default/grub)"
    else
        echo "$(date): ERROR: grub2-mkconfig failed, please check /etc/default/grub!"
        exit 1
    fi
    return 0
}

cpu_isolation_reset(){
    sed -i '/GRUB_CMDLINE_LINUX/ s/ isolcpus=[0-9,\-]\+//' /etc/default/grub
    grub_rebuild
}

cpu_isolation_add(){
    sed -i -e "/GRUB_CMDLINE_LINUX/ s/\"$/ isolcpus=${1}\"/" /etc/default/grub
    grub_rebuild
}

cpu_isolation(){
    conf_count=`grep "isolcpus" /etc/default/grub | grep -v "grep" | wc -l`
    inuse_count=`grep "isolcpus" /proc/cmdline | grep -v "grep" | wc -l`

    if [[ $conf_count != 0 && $inuse_count != 0 ]]
    then
        echo "$(date): INFO: cpu isolation is already setting and take effect or use reset!"
        echo "$(date): INFO: now conf is: $(grep isolcpus /etc/default/grub)"
        echo "$(date): INFO: now inuse is: $(cat /proc/cmdline)."
    elif [[ $conf_count != 0 && $inuse_count == 0 ]]
    then
        echo "$(date): INFO: cpu isolation is setted, please reboot to take effect or use reset!"
        echo "$(date): INFO: now conf is: $(grep isolcpus /etc/default/grub)."
    else
        echo "$(date): INFO: cpu isolation is not set, now start to set..."
        cpu_isolation_add ${1}
    fi
    return 0
}

parse_parameter() {
    if [[ "$1" == "show" ]]; then
        echo -e "==========当前grub配置信息=========="
	    grep "GRUB_CMDLINE_LINUX" /etc/default/grub
        echo -e "\n==========当前生效信息=========="
	    cat /proc/cmdline
        echo -e "\n==========cpu相关信息=========="
	    lscpu -e
        exit 0
    elif [[ "$1" == "reset" ]]; then
        echo "==========重置前grub配置信息=========="
	    grep "GRUB_CMDLINE_LINUX" /etc/default/grub
        echo -e "\n"
        cpu_isolation_reset
        echo -e "\n==========重置后grub配置信息=========="
	    grep "GRUB_CMDLINE_LINUX" /etc/default/grub
        exit 0
    elif [[ "$1" == "bind" ]]; then
    	if [[ x"$2" == "x" ]]; then
            echo "$(date): [ERROR]: 请指定需要隔离的cpu号!"
	        usage  
            exit 1
    	fi
        ISO_CPU_LIST=$2
        if ! check_cpu_list ${ISO_CPU_LIST}; then
            usage
            exit 1
        fi
        return 0
    else
	    usage
	    exit 1
    fi
}

main(){
    parse_parameter $@
    cpu_isolation ${ISO_CPU_LIST}
}

main $@
