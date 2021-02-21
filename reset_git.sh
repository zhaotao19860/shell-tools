#!/bin/bash
#Created by tom on 03/26/2020

set -e

SHELL_FOLDER=$(dirname $(readlink -f "$0"))
SHELL_NAME=$0

usage(){
    echo "===================================================================================="
    echo "说明："
    echo "    sh ./reset_git.sh git-repo-dir         //git仓库重置，即：删除历史版本，避免仓库越来越大"
    echo "    sh ./reset_git.sh git-repo-dir revert  //git仓库重置功能回退"
	echo "例子："
	echo "    重置：sh ./reset_git.sh /export/gitrepo/git-remote.git"
	echo "    回滚：sh ./reset_git.sh /export/gitrepo/git-remote.git revert"
	echo "注意："
	echo "    执行用户为git仓库用户；执行地址为git仓库所在服务器；"
    echo "===================================================================================="
	exit 1
}

get_repo_name(){
    para=$1
    file_name=$(echo ${para##*/})
    repo_name=$(echo ${file_name%%.*})
    echo ${repo_name}
}

get_repo_dir(){
    para=$1
    repo_dir=$(echo ${para%/*})
    echo ${repo_dir}
}

revert(){
    echo "$(date) [$SHELL_NAME][$LINENO] [INFO] start revert git[$1] ..."
    repo_dir=`get_repo_dir $1`
    repo_name=`get_repo_name $1`
    revert_git=$(find ${repo_dir} -maxdepth 1 -type d -name "${repo_name}*.bak.*" -print |sort -rn|head -1)
    mv $1 $1.error.$(date "+%Y%m%d%H%M%S")
    cp -rf ${revert_git} $1
    echo "$(date) [$SHELL_NAME][$LINENO] [INFO] revert git[$1] success."
}

reset(){
    echo "$(date) [$SHELL_NAME][$LINENO] [INFO] start reset git[$1] ..."
    repo_name=`get_repo_name $1`
    cd ${SHELL_FOLDER}
    if [ -d "./${repo_name}" ]; then
        \rm -rf ./${repo_name}
    fi

    # 拉取并重置本地仓库
    git clone --depth=1 localhost:$1
    cd ${repo_name}
    \rm -rf .git
    git init
    git add -A
    git commit -am "reinit repo at $(date "+%Y-%m-%d %H:%M:%S")"
    
    # 备份远端仓库
    mv $1 $1.bak.$(date "+%Y%m%d%H%M%S")

    # 重建远端仓库
    mkdir -p $1
    cd $1
    git init --bare

    # 关联本地库与远端库
    cd ${SHELL_FOLDER}/${repo_name}
    git remote add origin $1
    git push -f origin master
    git branch --set-upstream-to=origin/master master
    echo "$(date) [$SHELL_NAME][$LINENO] [INFO] reset git[$1] success."
}

main(){
    echo "$(date) [$SHELL_NAME][$LINENO] [INFO] start..."
    
    if [ $# -lt 1 ] 
    then
        usage
    elif [ $# -eq 1 ] 
    then
        reset $@
    elif [ $# -eq 2 -a $2 == "revert" ]
    then
        revert $1
    else
        usage
    fi

    echo "$(date) [$SHELL_NAME][$LINENO] [INFO] end..."
}

main $@