#!/bin/bash

#此脚本用于设置cpu隔离;

HUGEPAGE_TYPE=""
HUGEPAGE_SIZE=""

usage(){
    echo "===================================================================================="
    echo "使用说明："
    echo "    sh ./hugepage_set.sh help         //显示帮助信息"
    echo "    sh ./hugepage_set.sh show         //查看当前grub配置信息/当前生效信息/当前大页内存信息"
    echo "    sh ./hugepage_set.sh set 2M 8000  //预留8000个2M大页内存,共16G"
    echo "    sh ./hugepage_set.sh set 1G 64    //预留64个1G大页内存,共64G"
    echo "    sh ./hugepage_set.sh reset        //删除大页内存配置"
    echo "===================================================================================="
}

check_type(){
    if [[ $1 =~ ^2M|1G$ ]];then
        echo "hugepage type[$1] format OK."
        return 0
    else
        echo "hugepage type[$1] format ERROR."
        return 1
    fi
}

check_size(){
    if [[ $1 =~ ^[0-9]+$ ]];then
        echo "hugepage size[$1] format OK."
        return 0
    else
        echo "hugepage size[$1] format ERROR."
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

hugepage_reset(){
    sed -i '/GRUB_CMDLINE_LINUX/ s/ default_hugepagesz=[12]\{1\}[MG]\{1\}//' /etc/default/grub
    sed -i '/GRUB_CMDLINE_LINUX/ s/ hugepagesz=[12]\{1\}[MG]\{1\}//' /etc/default/grub
    sed -i '/GRUB_CMDLINE_LINUX/ s/ hugepages=[0-9]\+//' /etc/default/grub
    grub_rebuild
}

hugepage_add(){
    sed -i -e "/GRUB_CMDLINE_LINUX/ s/\"$/ default_hugepagesz=${HUGEPAGE_TYPE} hugepagesz=${HUGEPAGE_TYPE} hugepages=${HUGEPAGE_SIZE}\"/" /etc/default/grub
    grub_rebuild
}

hugepage_set(){
    conf_count=`grep "hugepagesz" /etc/default/grub | grep -v "grep" | wc -l`
    inuse_count=`grep "hugepagesz" /proc/cmdline | grep -v "grep" | wc -l`

    if [[ $conf_count != 0 && $inuse_count != 0 ]]
    then
        echo "$(date): INFO: hugepage is already setting and take effect or use reset!"
        echo "$(date): INFO: now conf is: $(grep hugepagesz /etc/default/grub)"
        echo "$(date): INFO: now inuse is: $(cat /proc/cmdline)."
    elif [[ $conf_count != 0 && $inuse_count == 0 ]]
    then
        echo "$(date): INFO: hugepage is setted, please reboot to take effect or use reset!"
        echo "$(date): INFO: now conf is: $(grep hugepagesz /etc/default/grub)."
    else
        echo "$(date): INFO: hugepage is not set, now start to set..."
        hugepage_add
    fi
    return 0
}

parse_parameter() {
    if [[ "$1" == "show" ]]; then
        echo -e "==========当前grub配置信息=========="
	    grep "GRUB_CMDLINE_LINUX" /etc/default/grub
        echo -e "\n==========当前生效信息=========="
	    cat /proc/cmdline
        echo -e "\n==========大页内存相关信息=========="
	    cat /proc/meminfo|grep Huge
        exit 0
    elif [[ "$1" == "reset" ]]; then
        echo "==========重置前grub配置信息=========="
	    grep "GRUB_CMDLINE_LINUX" /etc/default/grub
        echo -e "\n"
        hugepage_reset
        echo -e "\n==========重置后grub配置信息=========="
	    grep "GRUB_CMDLINE_LINUX" /etc/default/grub
        exit 0
    elif [[ "$1" == "set" ]]; then
    	if [[ x"$2" == "x" || x"$3" == "x" ]]; then
            echo "$(date): [ERROR]: 请指定需要设置的大页内存类型及大小!"
	        usage  
            exit 1
    	fi
        HUGEPAGE_TYPE=$2
        HUGEPAGE_SIZE=$3
        if ! check_type ${HUGEPAGE_TYPE} -o ! check_size ${HUGEPAGE_SIZE}; then
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
    hugepage_set
}

main $@
