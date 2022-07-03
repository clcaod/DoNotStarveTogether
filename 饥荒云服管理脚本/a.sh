#!/bin/bash
#
# 饥荒专服管理系统
# 
# 作者: 曹曹曹老板来了
# 2022-03-29
#

title="饥荒云服管理系统--LinuxOS"
DIR_PATH="${HOME}/.klei/DoNotStarveTogether/"
height=20
width=80
listheight=4
LEFT_VAL=10800				# 端口范围下边界
RIGHT_VAL=12000				# 端口范围上边界
stop_time=30				# 停止服务器倒计时

# 世界的基本信息
game_mode=""
max_players=""
cluster_name=""
cluster_description=""
server_port=""
cluster_key=""
master_port=""
caves_port=""

##################################################
# 弹框消息反馈
#
# 参数:
#     msg : 反馈的信息 
#   isEnd : 0代表结束,1代表返回主界面 
#   
# 返回值:
#    NULL
##################################################
_sendMsg(){
  msg=$1
  isEnd=$2
  whiptail --title "${title}" --msgbox "\n${msg}" --fb  ${height}  ${width}
}

###################################################
# 读取ini配置文件信息
#
# 参数:
#     INFILE : 配置文件全路径名
#   SENCTION : 配置文件中的节 配置文件中 [ ] 内的字段
#       ITEM : 对应key字段
#
# 返回值:
#      value : 对应key的value值
####################################################
_readINI(){
 INIFILE=$1; SECTION=$2; ITEM=$3
 value=$(awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$ITEM'/{print $2;exit}' $INIFILE)
 echo ${value}
}

####################################################
# 检查进程是否存在
# 
# 参数:
#   PS_NAME : 进程名称
# 
# 返回值:
#      psid : 进程PID,如果不存在该进程则返回0
####################################################  
_checkpid(){
  psid=0
  local PS_NAME=$1
 
  app_pid=`ps -ef|grep ${PS_NAME}|grep -v grep|awk 'NR==1'|awk '{print $2}'`
  if [[ -n "${app_pid}" ]];then
    psid=$app_pid
  fi
  echo ${psid}
}

####################################################
# 端口检测,如果存在则分配指定范围内随机端口
#
# 全局变量:
#   LEFT_VAL : 端口左边界
#  RIGHT_VAL : 端口右边界
#
# 参数:
#       PORT : 待检测端口号
#
# 返回值:
#   ret_port : 未被占用的端口号,如果本身未被占用则返回本身
#####################################################
_checkport(){
  PORT="$1"
 
  # 检测端口占用
  while lsof -i:"${PORT}" >/dev/null ; do
    PORT=$((RANDOM%$(( ${RIGHT_VAL} - ${LEFT_VAL} )) + ${LEFT_VAL} ))

    if  ! lsof -i:"${PORT}" >/dev/null ; then
      echo ${PORT}
      return
    fi
  done

  # 未进入while循环执行
  echo ${PORT}
}

#####################################################
# 列出指定路径下目录名
#
# 全局变量:
#      DIR_PAHT : 目录全路径
# 
# 返回值:
#   dir_arr : 目录名称数组
#####################################################
_listDir(){
  dir_list=$(ls -l ${DIR_PATH}|awk '/^d/ {print $NF}')
  dir_arr=(${dir_list})
  echo ${dir_arr[@]}
}

#####################################################
# 拼接whiptail输入框
#
# 参数:
#    TEXT : 输入框文本
#
# 返回值:
#   input : 输入框内容
#####################################################
_inputbox(){
  TEXT=$1
  input=$(whiptail --title ${title} --inputbox "\n${TEXT}\n" \
   --ok-button "确定" --cancel-button "取消"  ${heigth} ${width} 3>&1 1>&2 2>&3)

  echo ${input}
}

#####################################################
# 拼接whiptail文本窗口
#
# 参数:
#   log_file : 日志文件全路径
#
# 返回值:
#   NULL
##################################################### 
_viewServerLog(){
  log_file=$1
  whiptail --title "${title}/日志查看" --textbox ${log_file} --ok-button "确定" --scrolltext 30 80
}


#####################################################
# 拼接whiptail复选框列表checklist(上层调用应该过滤空目录)
#
# 参数:
#   ITEMS : 列表数组
#   TITLE : 弹框标题
#
# 返回值:
#   opts  : 用户的选择项(eg:"0" "1" "2")
#####################################################
_checklist(){
  ITEMS=$1
  TITLE=$2
  
  append_cmd=""
  num=1
  for name in ${dir_arr[@]}; do
    append_cmd+="${num} ${name} OFF "
    let num++
  done

  opts=$(whiptail --title "${TITLE}" --checklist "\n按下空格键进行勾选,按下Tab键将切入确定/返回键\n\n请选择存档操作:" ${height} ${width} ${listheight} \
    --notags --ok-button "确定" --cancel-button "返回" ${append_cmd} \
    3>&1 1>&2 2>&3)

  echo ${opts}
}

###################################################
# screen窗口管理
#
# 参数:
#   screen_name : 窗口名称
#        method : 执行动作方法名(启动还是停止)
#           cmd : 需要给窗口发送的命令
#
# 返回值:
#      msg : 执行结果返回0,失败返回1并给出error_msg
###################################################
error_msg=""
_screen(){
  screen_name=$1
  cmd=$2
  method=$3

  # 检查进程
  ret=$(_checkpid ${screen_name})
  # 开启世界和关闭世界的逻辑判断是不一样的
  if [[ "start" == "${method}" ]]; then
    if [[ ${ret} -ne 0 ]]; then
      echo ""
      error_msg="世界已启动,无法再次查看!\n\n窗口命令: screen -r ${ret}"
      return 1
    else
      # 开启守护进程窗口
      screen -dmS ${screen_name}
      # 给窗口发送命令并执行
      screen -x -S ${screen_name} -p 0 -X stuff "$cmd"
    fi
  # 停止｜广播一样
  else
    if [[ ${ret} -eq 0 ]]; then
      error_msg="世界还未启动!"
      return 1
    else
      screen -x -S ${screen_name} -p 0 -X stuff "$cmd"
    fi
  fi
}

##################################################
# 读取配置信息
#  
# 参数:
#   cluster : 存档名称
#
# 返回值:
#   NULL
##################################################
_readInfo(){
  cluster=$1

  # 文件全路径
  cluster_ini="${DIR_PATH}${dir}/cluster.ini"
  master_ini="${DIR_PATH}${dir}/Master/server.ini"
  caves_ini="${DIR_PATH}${dir}/Caves/server.ini" 

  # 世界的基本信息
  game_mode=$(_readINI "${cluster_ini}" "GAMEPLAY" "game_mode")
  max_players=$(_readINI "${cluster_ini}" "GAMEPLAY" "max_players")
  cluster_name=$(_readINI "${cluster_ini}" "NETWORK" "cluster_name")
  cluster_description=$(_readINI "${cluster_ini}" "NETWORK" "cluster_description")
  server_port=$(_readINI "${cluster_ini}" "SHARD" "master_port")
  cluster_key=$(_readINI "${cluster_ini}" "SHARD" "cluster_key")
  master_port=$(_readINI "${master_ini}" "NETWORK" "server_port")
  caves_port=$(_readINI "${caves_ini}" "NETWORK" "server_port")
}


# 启动世界(重构后方法)
# 1. 启动世界前列举存档目录，如果没有则提示先创建世界
# 2. 根据列举的存档目录，读取内置配置文件和token判断，缺失文件则提示无效目录
# 3. 判断窗口是否已存在,根据screen窗口判断世界是否真正启动是不可靠的,但是大多数情况是适用的
#    这里先这样实现,后续存在优化技术再进行改进 TODO (BUG 如果仅仅开启了窗口并未执行饥荒启动
#。  脚本,也会被误判为世界已启动)
function_start(){
  dir_arr=$(_listDir ${DIR_PATH})
  
  # 对数组判断,空目录需要提示创建世界
  if [[ ${#dir_arr} -eq 0 ]]; then
    # 创建世界逻辑
    _sendMsg "\n\n\n\n找不到任何世界存档,请先创建世界!" 1
  else  
    OPTIONS=$(_checklist "${dir_arr[@]}" "${title}/启动世界")
    # 如果选项为空代表未选择或取消操作需要返回
    if [[ -z ${OPTIONS} ]]; then
      bash $0
    else
      for opt in ${OPTIONS}; do
	# OPTIONS选项中为:"1" "2",需要去双引号
        # 选项标号对应存档数组的下标+1,所以需要获取一下数组索引
        idx=$(echo $opt |sed s/\"//g)
        dir=$(echo ${dir_arr[@]}|awk '{print $'$idx'}')
        # 文件全路径
        token_file="${DIR_PATH}${dir}/cluster_token.txt"
        cluster_ini="${DIR_PATH}${dir}/cluster.ini"

        # 校验token文件是否存在
        if [ ! -f "${token_file}" ] || [ $(cat "${token_file}"|wc -c) -eq 0 ] ;then
	  # 列举存档信息
	  if [[ -f ${cluster_ini} ]]; then
 	    _readInfo ${dir}
            _sendMsg "存档:${dir} \n\n未找到token,存档将不会启动,请先配置token!\n\n世界:${cluster_name}\n\n描述:${cluster_description}"
	  else
            _sendMsg "存档:${dir} \n\n\n可能是非饥荒存档目录,请确认!" 
          fi
        else
          # 启动游戏需要判断端口是否被占用(服务器+世界+洞穴)
          _readInfo ${dir}
          server_port=$(_checkport ${server_port})
          master_port=$(_checkport ${master_port})
	  caves_port=$(_checkport ${caves_port})
	  # 端口写入ini文件
          sed -i "s/\(^master_port.*\)/master_port = ${server_port}/g" ${cluster_ini}
 	  sed -i "s/\(^server_port.*\)/server_port = ${master_port}/g" ${master_ini}
	  sed -i "s/\(^server_port.*\)/server_port = ${caves_port}/g" ${caves_ini}
	  
          # 窗口函数执行(执行成功返回0,执行失败返回1并写入全局变量error_msg)
          # 给窗口发送的命令
          master_cmd="./dontstarve_dedicated_server_nullrenderer_x64 -console -cluster ${dir} -shard ${Master}$(printf \\r)";   
          caves_cmd="./dontstarve_dedicated_server_nullrenderer_x64 -console -cluster ${dir} -shard ${Caves}$(printf \\r)";   
	  if _screen "${dir}_Master" "${master_cmd}" "start" ; then
	    _screen "${dir}_Caves" "${caves_cmd}" "start"
	    sleep 3
	    _sendMsg "存档:${dir} \n\n启动成功!  点击下方<OK>查看启动日志\n\n世界:${cluster_name}\n\n描述:${cluster_description}\n\n人数:${max_players}\n\n模式:${game_mode}\n\n"
	   
	    _viewServerLog "${DIR_PATH}${dir}/Master/server_log.txt"
	  else
 	    _sendMsg "存档:${dir} \n\n启动失败!\n\n错误信息:${error_msg}"
	  fi
        fi
      done
    fi
  fi   
}

# 停止服务
# 1. 先给窗口发送关闭消息,(默认)30秒后自动停止服务
# 2. 进度条结束杀死进程结束任务,停止服务需要回到主界面
function_stop(){
 dir_arr=$(_listDir ${DIR_PATH})

  # 对数组判断,空目录需要提示创建世界
  if [[ ${#dir_arr} -eq 0 ]]; then
    # 创建世界逻辑
    _sendMsg "\n\n\n\n找不到任何世界存档,请先创建世界!" 1
  else  
    OPTIONS=$(_checklist "${dir_arr[@]}" "${title}/停止世界")
    # 如果选项为空代表未选择或取消操作需要返回
    if [[ -z ${OPTIONS} ]]; then
      bash $0
    else
      for opt in ${OPTIONS}; do
        # OPTIONS选项中为:"1" "2",需要去双引号
        # 选项标号对应存档数组的下标+1,所以需要获取一下数组索引
        idx=$(echo $opt |sed s/\"//g)
        dir=$(echo ${dir_arr[@]}|awk '{print $'$idx'}')
        
        cluster_ini="${DIR_PATH}${dir}/cluster.ini"
        if [[ -f ${cluster_ini} ]]; then
 	_readInfo ${dir}
	if (whiptail --title "${title}/停止世界" --yes-button "确定" --no-button "取消" --yesno "存档:${dir},确定停止该世界吗?世界:${cluster_name}" 10 60) then
  	  cmd="c_announce(\"服务器将在30秒后关闭!\")$(printf \\r)"
	  
	  if _screen "${dir}_Master" "${cmd}" "stop" ; then
	    _screen "${dir}_Caves" "${cmd}" "stop"
	    for i in {1..2}; do
	      _screen "${dir}_Master" "${cmd}" "stop"
	      _screen "${dir}_Caves" "${cmd}" "stop"
	      sleep 1
            done
            # 进度条
	    {
	      for ((i = 0 ; i <= 100 ; i+=4)); do
		sleep 1
		echo $i
	      done
	    } | whiptail --title "${title}/倒计时" --gauge "服务器即将关闭..." 6 60 0

	    # 倒计时结束关闭窗口
	    cmd="c_shutdown(true)$(printf \\r)"
	    _screen "${dir}_Master" "${cmd}" "stop"
	    _screen "${dir}_Caves" "${cmd}" "stop"
	    
	    kill -9 $(_checkpid "${dir}_Master")
	    kill -9 $(_checkpid "${dir}_Caves")
	    screen -wipe
	    _sendMsg "存档:${dir} \n\n服务器已关闭!\n\n世界:${cluster_name}\n\n描述:${cluster_description}\n\n人数:${max_players}\n\n模式:${game_mode}\n\n"
	  else
	    _sendMsg "存档:${dir} \n\n停止失败!\n\n错误信息:${error_msg}"
	  fi
	else
	  bash $0
	fi 
          else
	    _sendMsg "存档:${dir} \n\n\n可能是非饥荒存档目录,请确认!"
          fi
      done
     fi 
  fi
}


# 启动世界核心方法
error_msg=""
function_start_screen(){
  # 默认只适用一个世界一个洞穴场景,这里上游传递参数格式如:Cluster_1_Master
  local NODE_NAME=$1
    checkpid ${NODE_NAME}
    if [[ $psid -ne 0 ]];then
        error_msg="窗口 ${NODE_NAME} 已经存在了!\n\n输入命令: screen -r ${psid} 可进入窗口."
	return 1
    fi
    # 开启守护进程窗口
    screen -dmS ${NODE_NAME}
    # 给窗口发送的命令
    cmd="./dontstarve_dedicated_server_nullrenderer_x64 -console -cluster ${NODE_NAME%_*} -shard ${NODE_NAME##*_}$(printf \\r)";
    # 给窗口发送命令并执行
    screen -x -S ${NODE_NAME} -p 0 -X stuff "$cmd"
    
    if [[ $? -eq 0 ]];then
        return 0
    else
	error_msg="未知错误,或许执行窗口命令错误."
        return 1
    fi
}

# 广播消息核心方法(有时间再和上面方法进行重组)
function_announce_screen(){
  local NODE_NAME=$1
  local send_msg=$2
  checkpid ${NODE_NAME}
  if [[ $psid -ne 0 ]];then
    # 给窗口发送的命令
    cmd="c_announce(\"${send_msg}\")$(printf \\r)"
    # 给窗口发送命令
    screen -x -S ${NODE_NAME} -p 0 -X stuff "$cmd"
    
    if [[ $? -eq 0 ]] ; then
      return 0
    else
      error_msg="未知错误,或许执行窗口命令错误."
      return 1
    fi
  else
    # 不存在窗口则给出错误信息
    error_msg="窗口 ${NODE_NAME} 不存在,无法发送消息!"
    return 1
  fi 
}


# 列举存档,入参为需要存档执行的动作(启动,停止,广播消息等),格式为[start|stop|announce]去除前缀function_
function_list(){
  method=$1
  send_msg=$2
  if [[ "start" == ${method} ]]; then
    title="${title}/启动世界"
  elif [[ "announce" == ${method} ]] ; then
    title="${title}/广播消息"
  fi

  # 列举出已有存档(注意只有目录才应该被列出来)
  dir_list=$(eval ls -l ${DIR_PATH}|grep '^d'|awk '{print $9}')
  # 根据存档选择性启动,如果没有存档则提示创建世界
  if [[ -z ${dir_list} ]]; then
    # 调用创建世界的功能
    echo "创建世界"
  else
    # 不为空则列举所有存档复选框选择启动
    append_cmd=""
    num=1
    for name in ${dir_list}; do
        append_cmd+="${num} ${name} OFF "
        let num++
    done    

    OPTION=$(whiptail --title "${title}" --checklist "按下空格键进行勾选,按下Tab键将切入确定/返回键\n\n请选择存档操作:" ${height} ${width} ${listheight} \
    --ok-button "确定" --cancel-button "返回" --notags ${append_cmd} \
    3>&1 1>&2 2>&3)
    
    # 根据列举的目录添加到checklist
    if [[ $? -eq 0 ]]; then
      # 遍历存档
      dir_arr=(${dir_list})
      for opt in ${OPTION};do
	# OPTIONS选项中为:"1" "2",需要去双引号
	# 选项标号对应存档数组的下标+1,所以需要获取一下数组索引
        idx=$(echo $opt |sed s/\"//g)
        dir_name=${dir_arr[$(expr $idx - 1)]}
        
        # 根据方法名不同执行不同的操作
        if [[ "start" == ${method} ]] ; then
          # 抽取启动核心方法(function_start_screen)便于维护
          if function_start_screen "${dir_name}_Master" ; then       
            function_msg "${dir_name} 世界启动成功!"
          else
            function_msg "${dir_name} 世界启动失败!\n\n${error_msg}"
          fi
          if function_start_screen "${dir_name}_Caves" ; then
	    function_msg "${dir_name} 洞穴启动成功!"
	  else
	    function_msg "${dir_name} 洞穴启动失败!\n\n${error_msg}"
	  fi
	elif [[ "announce" == ${method} ]] ; then
	  if function_announce_screen "${dir_name}_Master" "${send_msg}" ; then
	    function_msg "${dir_name} 消息发送成功!"
	  else
	    function_msg "${dir_name} 消息发送失败!\n\n${error_msg}"
	  fi
	  if function_announce_screen "${dir_name}_Caves" "${send_msg}" ; then
	    function_msg "${dir_name} 消息发送成功!"
	  else
	    function_msg "${dir_name} 消息发送失败\n\n${error_msg}"
	  fi 
	fi
      done
    else
      # 取消操作返回主界面(调用自己)
      bash $0
    fi     
  fi
}

# 给世界发送消息(如通知玩家服务器明天将进入维护)
function_announce(){
  send_msg=$(whiptail --title "${title}/广播消息" --inputbox "\n\n请输入需要广播的消息:\n" --ok-button "发送" --cancel-button "取消" ${height} ${width} 3>&1 1>&2 2>&3)
    
  if [[ $? -eq 0 ]]; then
    function_list "announce" "${send_msg}"
  else
    bash $0
  fi
}


# 首页欢迎界面 
OPTION=$(whiptail --title "${title}" --menu "\n" --ok-button "下一步" --cancel-button "退出"  ${height} ${width} ${listheight} \
 "1" "启动世界" "2" "停止世界" "3" "创建世界" "4" "广播消息"\
  3>&1 1>&2 2>&3)

# 功能项
case ${OPTION} in
  '1')
    # 启动游戏
    function_start
    ;;
  '2')
    # 停止世界
    function_stop
    ;;
  '3')
    # 创建世界
    function_create
    ;;
  '4')
    # 广播消息
    function_announce
    ;;
  *)
    exit 0
esac

