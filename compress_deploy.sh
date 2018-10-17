#! /bin/bash
Date=`date +%F_%H-%M-%S`

if [ $# -lt 4 ];then
        echo -e "\n-------------------------------------------------\n\n\t-- Usage:  ${0} Job_name app_name action rollback_version flag\n\n  -$'1'\tJenkins项目名\n  -$'2'\t发布war包名称\n  -$'3'\t确认执行update or rollback\n  -$'4'\t确认回退版本号\t\n\n--------------------------------------------------\n\n" && exit
fi

#===============
#  nfs 挂载
#===============
nfs_ip='10.133.115.244'  # 可能需要修改
nfs_dir='/app/jenkins_data/workspace'  # 可能需要修改
war_data="/srv" # 可能需要修改
war_bak_path='/app/war_bak' # 可能需要修改
	nfs_judge=`rpm -qa | grep nfs-utils &>/dev/null && rpm -qa | grep rpcbind &>/dev/null && echo 1 || echo 0`
	if [ ${nfs_judge} -eq 0 ];then yum install -y nfs-utils rpcbind || exit;fi
	mount -t nfs ${nfs_ip}:${nfs_dir} ${war_data}
#=============
#定义全局变量
#=============

export JAVA_HOME=/usr/local/jdk
export CLASSPATH=$JAVA_HOME/lib
export PATH=$PATH:$JAVA_HOME/bin
export TOMCAT_HOME=/usr/local/tomcat
export TOMCAT_LOG_PATH=/app/tomcat/logs/
#================
# 定义tomcat变量
#================
tomcat_user='appuser'
tomcat_start='/usr/local/tomcat/bin/catalina.sh start'
tomcat_stop='/usr/local/tomcat/bin/catalina.sh stop'

#======================================
# 定义最新war包存储目录及war包名称获取
#======================================
job_name="${1}"
war_name=${2}
confirm_action=${3}
Rollback_version=${4}
war_path="${war_data}/${job_name}/target"
war_all_name=`cd  ${war_path};ls -1t *.war | head -n1`
war_version=`echo ${war_all_name} | awk -F '.war' '{print $1}'`
url="http://localhost:8080/${war_version}" # 可能需要修改

#==========================
# 以下为可能需要修改的变量
#==========================

app_path="${TOMCAT_HOME}/webapps"

[[ -d ${war_data} ]] || mkdir -p ${war_data}
[[ -d ${war_bak_path} ]] || mkdir -p ${war_bak_path}
[[ -d ${TOMCAT_LOG_PATH} ]] || mkdir -p ${TOMCAT_LOG_PATH}
[[ -f ${war_path}/${war_all_name} ]] || echo -e "\n\n*****\t${war_all_name}:   No such file or directory\t******\n\n"
[[ -f ${war_path}/${war_all_name} ]]  || exit

#再次声明旧文件备份目录
backup_dir=${war_bak_path}
# 最新的备份文件保留几份
files=10
#   备份
#=========
Clean_backups () {
	cd ${backup_dir}; Total=$(ls | wc -l) ;Num=$((${Total} - ${files}))
	echo -e "\n\n====::))\t当前${backup_dir}下共计${Total}个备份文件\t((::====\n\n"
	if [ ${Num} -gt 0 ];then
		echo -e "\n\n******\t开始清理备份文件\t******\n\n"
		for file in $(cd ${backup_dir}; ls -1t | tail -n ${Num});do echo -e "\n---\t${file} is deleted\t---\n";rm $file;done
	else 
		echo -e "\n\n----\t${backup_dir}下备份文件数量小于${files}个,将不再进行清理...\t----\n\n"
	fi
}
#==========================
#解压版tomcat部署过程
#==========================
war_backup () {
[ -d ${war_bak_path} ] || mkdir -p ${war_bak_path}
judge=`ls ${app_path}/${war_name}*.war | wc -l`
if [ ${judge} -gt 0 ];then
	old_war_name=`cd ${app_path}; ls ${war_name}*.war | awk -F '.war' '{print $1}'`
	cd ${app_path}; tar zcf ${old_war_name}.bak${Date}.tgz   ./${old_war_name}*
	if [ $? -eq 0 ]
	then 
		cd ${app_path};mv ${old_war_name}.bak${Date}.tgz ${war_bak_path};
		cd ${app_path}; rm -rf ./${old_war_name}* && echo -e "\n\n---------->\t${Date}\t<-------\n\==::))\t${old_war_name}备份成功...\t((::==";
	else 
		echo -e "\n\n\n******\t ${old_war_name} is backup Failed.....\t****\n\n"
	fi
else
	echo -e "\n\n\n********\t\t${war_name}相关版本war包不存在,不再执行数据备份....\t\t*********\n\n\n";
fi
}

war_deploy () {	
	cd ${war_path} ; cp ${war_all_name} ${app_path};
	cd ${app_path}; unzip ${war_all_name} -d ${war_version} &>/dev/null && echo -e "\n\n\n unzip ${war_all_name}:  [\tOK\t]\n\n";
	ps -ef |grep tom | grep -v grep | awk '{print $2}' >  /usr/local/bin/pid
	sudo -u root cat /usr/local/bin/pid | sort | uniq > /usr/local/bin/kaleido.pid
 	while read kaleido_pid; do kill -9 ${kaleido_pid} && echo -e "\nkilled ${kaleido_pid}" ;done < /usr/local/bin/kaleido.pid
	chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_HOME}
	chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_LOG_PATH}
	ps -ef | grep tomcat | grep -v grep && echo -e "\n\n\n"
	read -t 3
	sudo -u ${tomcat_user} ${tomcat_start}
	ps -ef | grep tomcat  
}


#  健康检查
#===========

health_check () {
for i in `seq 1 6`
do
        read -t ${i}
        echo -e "\n\n====::))\tstarting health check for ${i}\t((::====\n\n"
        timeout 10s curl ${url} --head -s 
        if [ $? -eq 0 ];then
                echo -e "\n==\n====\n======\n\n------->\t${war_version} deploy is Successfulled\t<--------\n\n\n" ;break 
        elif [ $? -ne 0 ];then
                #echo -e "\n\n\n*******\t\t${project_name}   deploy is failed\t********\n\n";
                if [ ${i} -eq 6 ];then
                        echo -e "\n\n\t---->\t应用${war_all_name}发布失败,即将开始回滚...\t<----\n\n"
                        Rollback 1
                fi

        fi
done
}
#=== 回退变量====

mount_dir=${war_data}
APP_BAK="${war_bak_path}"
APP_NAME="${war_name}"

#======= 回退 ========

Rollback () {
#    Global 
#numr=${Rollback_version}
numr=${1}
old_war_name=`cd ${app_path}; ls ${war_name}*.war | awk -F '.war' '{print $1}'`
#开始清理最新数据
		cd ${app_path}; rm -rf ./${old_war_name}* 
#开始恢复备份数据
        [[ -f $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1) ]] || echo -e "\n\n\t****\t备份文件不存在,回滚失败...\t****\n\n"
        [[ -f $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1) ]] || exit
backupfile_name=$(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1)
        echo -e "\n\n\t---->\t开始恢复备份文件: $(ls -1t ${APP_BAK}/${APP_NAME}*| head -n ${numr} | tail -n 1)...\t<----\n\n"
#   局部 
        tar xf  ${backupfile_name} -C ${app_path}/  &>/dev/null && echo -e "\n\n\n 解压 ${backupfile_name}:  [\tOK\t]\n\n";
        ps -ef |grep tom | grep -v grep | awk '{print $2}' >  /usr/local/bin/pid
        sudo -u root cat /usr/local/bin/pid | sort | uniq > /usr/local/bin/deploy.pid
        while read init_pid; do kill -9 ${init_pid} && echo -e "\nkilled ${init_pid}" ;done < /usr/local/bin/deploy.pid
        chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_HOME}
        chown -R ${tomcat_user}:${tomcat_user} ${TOMCAT_LOG_PATH}
        read -t 3
        sudo -u ${tomcat_user} ${tomcat_start}
                ps -ef | grep tomcat  
# ==== 再次进行健康检查 =====
        for i in `seq 1 6`
        do
                read -t ${i}
                echo -e "\n\n====::))\tstarting health check for ${i}\t((::====\n\n"
        timeout 10s curl ${url} --head -s 
        if [ $? -eq 0 ];then
                echo -e "\n==\n====\n======\n\n------->\t${war_version} deploy is Successfulled\t<--------\n\n\n" ;break
        else
                if [ ${i} -eq 6 ];then
                        echo -e "\n\n\t---->\t${APP_NAME}回滚失败，请手动恢复后重试...\t<----\n\n"
                fi

        fi
done
}

# 构建后操作
Post_steps () {

        echo -e "\n当前所有备份文件对应序号如下:\n\n--------------------------\n"
        a1=0
        for i in `cd ${APP_BAK};ls -1t ${APP_NAME}*`
        do
                a1=$(( ${a1} + 1 )) 
                echo -e "\n${a1} :\t${i}\n"
        done
        sudo umount ${mount_dir}
}



case ${confirm_action} in
update)
        Clean_backups && war_backup && war_deploy && health_check && Post_steps
;;
rollback)
        Rollback ${Rollback_version}
        Post_steps
;;
*)
        echo -e "\n\n\t----> Usage: ${0} project_name War_name confirm:(update/rollback)  Rollback_version\n\n"
        sudo umount ${mount_dir}
;;
esac












