#!/bin/bash
#
# 饥荒专服管理系统
#
# Author: tough
# 2022-07-02
#
# GitHub链接：https://github.com/clcaod/DoNotStarveTogether.git
#

#-------------------------------------------配置区----------------------------------------------------------------------#

# 目录路径配置 ###########################################################################################################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"      # 使用这条语句需要脚本放置在饥荒安装目录的bin目录下
#SCRIPT_DIR="$(cd ~/dstserver/bin64/ && pwd)"                      # 使用这条语句需要替换为实际安装目录

CLUSTER_PATH="$(cd ~/.klei/DoNotStarveTogether/ && pwd)"            # 饥荒默认存档目录，如果不正确需要修改

# 单服务器多开时，端口冲突分配的端口范围 #####################################################################################

LEFT_VAL=10800				            # 端口范围下边界
RIGHT_VAL=12000				            # 端口范围上边界

# 时长等待配置 ###########################################################################################################

TIME_START_TIP=10                 # 世界启动时间,单位 秒
TIME_STOP_TIP=5                   # 世界关闭倒计时，单位 秒
TIME_EXIT_SCREEN=5                # 世界执行关闭命令后等待退出窗口时间(时间过短会导致服务关闭但是窗口未退出的情况)。单位 秒
TIME_REGENERATE_WORLD_TIP=5       # 世界重置倒计时，单位 秒
TIME_ROLLBACK_TIP=5               # 世界回档倒计时，单位 秒

# 脚本位置参数接收(勿修改) #################################################################################################

COMMAND=$1                        # 功能命令
CLUSTER_NAME=$2                   # 存档名称
OPTION=$3                         # 不同命令对应的可选项

# 服务器端提示语句 ########################################################################################################

CLOSE_MSG="服务器将在${TIME_STOP_TIP}秒后关闭！"                               # 服务器关闭给服务器玩家的提示语句
ROLLBACK_MSG="服务器将在${TIME_ROLLBACK_TIP}秒后回档，回档次数: ${OPTION} !"     # 世界回档给玩家的提示语句
REGENERATE_WORLD_MSG="服务器将在${TIME_REGENERATE_WORLD_TIP}秒后重置!"         # 世界重置给玩家的提示语句

#-------------------------------------------核心方法区-------------------------------------------------------------------#

# 进度条
_progress(){
  time=$1

  # 根据时间计算出循环间隙
  gap=$(echo "scale=1; $time/25 " |bc)

  i=0
  str="#"
  ch=('|' '\' '_' '/')
  index=0
  while [ $i -le 25 ];do
    printf "[%-25s][%d%%][%c]\r" $str $(($i*4)) "${ch[$index]}"
    str+="#"
    let i++
    let index=i%4
    sleep "$gap"
  done
  printf "\n"
}

# 完整的语法提示
_usageTip(){
    echo "Usage: "
    echo "  bash $0 <command> <cluster_name> <option>"
    echo ""
    echo "  尝试 'bash dst.sh <start|stop|restart|status|send|-r|rollback|-h|--help> <cluster_name> [option]'"
    echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
    echo ""
    echo "Commands:"
    echo "  start     启动世界，默认开始世界+洞穴，添加option可指定世界或者洞穴"
    echo "            用法："
    echo "                bash $0 start <cluster_name> [Master|Caves]"
    echo "            举例："
    echo "                bash dst.sh start Cluster_1         开启存档 Cluster_1 的主世界和洞穴"
    echo "                bash dst.sh start Cluster_1 Master  仅开启存档 Cluster_1 的主世界"
    echo ""
    echo "  stop      停止世界，默认停止世界+洞穴，添加option可指定世界或者洞穴"
    echo "            用法："
    echo "                bash $0 stop <cluster_name> [Master|Caves]"
    echo "            举例："
    echo "                bash $0 stop Cluster_1              停止存档 Cluster_1 的主世界和洞穴"
    echo "                bash $0 stop Cluster_1 Caves        仅停止存档 Cluster_1 的洞穴"
    echo ""
    echo "            注：饥荒关闭主世界默认洞穴会相应关闭，因此 bash $0 stop Cluster_1 等同 bash $0 stop Cluster_1 Master"
    echo ""
    echo "  restart   重启世界，默认重启世界+洞穴。"
    echo "            用法："
    echo "                bash $0 restart <cluster_name> "
    echo "            举例："
    echo "                bash $0 restart Cluster_1           重启开启存档 Cluster_1 的主世界和洞穴"
    echo ""
    echo "  status    查询存档（主世界）运行状态"
    echo "            用法： "
    echo "                bash $0 restart <cluster_name>"
    echo "            举例："
    echo "                bash $0 restart Cluster_1           重启开启存档 Cluster_1 的主世界和洞穴"
    echo ""
    echo "  send      给世界和洞穴发送消息通知"
    echo "            用法："
    echo "                bash $0 send <cluster_name> [message]"
    echo "            举例："
    echo "                bash $0 send Cluster_1  '新增Mod，服务器将在下午重启!'  "
    echo ""
    echo "  -r        regenerateWorld 重置世界"
    echo "            用法： "
    echo "                bash $0 -r <cluster_name>"
    echo "            举例："
    echo "                bash $0 -r Cluster_1                  重置存档 Cluster_1   "
    echo ""
    echo "  rollback  regenerateWorld 重置世界"
    echo "            用法："
    echo "                bash $0 rollback <cluster_name> [option]"
    echo "            举例："
    echo "                bash $0 rollback Cluster_1           回档 Cluster_1 默认 1 次 "
    echo "                bash $0 rollback Cluster_1 3         回档 Cluster_1 指定 3 次 "
    echo ""
    echo "Cluster_name:"
    echo "            存档名称，默认格式 Cluster_# ,#为数字1,2,...n"
    echo "            存档存在时正常执行，存档不存在时候启动则会在默认目录创建存档目录"
    echo ""
    echo "Options:"
    echo "  Master    需搭配命令 start|stop 使用，用于指定世界"
    echo "  Caves     需搭配命令 start|stop 使用，用于指定洞穴"
    echo "  Message   需搭配命令 send 使用，为字符串格式，给服务器发送的通知内容"
    echo "  count     需搭配命令 rollback 使用，为数字格式，指定回档的次数"
    exit 1
}

# 简短的语法提示
_simpleUsageTip(){
      echo "Usage: "
      echo "  bash $0 <command> <cluster_name> <option>"
      echo ""
      echo "  尝试 'bash dst.sh <start|stop|restart|status|send|-r|rollback|-h|--help> <cluster_name> [option]'"
      echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
      exit 1
}

# 开启世界功能语法提示
_startUsageTip(){
      echo "Usage: "
      echo "  bash $0 <command> <cluster_name> <option>"
      echo ""
      echo "  尝试 'bash dst.sh <start|stop|restart|status|send|-r|rollback|-h|--help> <cluster_name> [option]'"
      echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
      echo ""
      echo "Commands:"
      echo "  start     启动世界，默认开始世界+洞穴，添加option可指定世界或者洞穴"
      echo "            用法："
      echo "                bash $0 start <cluster_name> [Master|Caves]"
      echo "            举例："
      echo "                bash dst.sh start Cluster_1         开启存档 Cluster_1 的主世界和洞穴"
      echo "                bash dst.sh start Cluster_1 Master  仅开启存档 Cluster_1 的主世界"
      exit 1
}

# 停止世界功能语法提示
_stopUsageTip(){
    echo "Usage: "
    echo "  bash $0 <command> <cluster_name> <option>"
    echo ""
    echo "  尝试 'bash dst.sh <start|stop|restart|status|send|-r|rollback|-h|--help> <cluster_name> [option]'"
    echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
    echo ""
    echo "Commands:"
    echo "  stop      停止世界，默认停止世界+洞穴，添加option可指定世界或者洞穴"
    echo "            用法："
    echo "                bash $0 stop <cluster_name> [Master|Caves]"
    echo "            举例："
    echo "                bash $0 stop Cluster_1              停止存档 Cluster_1 的主世界和洞穴"
    echo "                bash $0 stop Cluster_1 Caves        仅停止存档 Cluster_1 的洞穴"
    echo ""
    echo "            注：饥荒关闭主世界默认洞穴会相应关闭，因此 bash $0 stop Cluster_1 等同 bash $0 stop Cluster_1 Master"
    exit 1
}

# 重启世界功能语法提示
_restartUsageTip(){
    echo "Usage: "
    echo "  bash $0 <command> <cluster_name> <option>"
    echo ""
    echo "  尝试 'bash dst.sh <start|stop|restart|status|send|-r|rollback|-h|--help> <cluster_name> [option]'"
    echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
    echo ""
    echo "Commands:"
    echo "  restart   重启世界，默认重启世界+洞穴。"
    echo "            用法："
    echo "                bash $0 restart <cluster_name> "
    echo "            举例："
    echo "                bash $0 restart Cluster_1           重启开启存档 Cluster_1 的主世界和洞穴"
    exit 1
}

# 查询状态功能语法提示
_statusUsageTip(){
    echo "Usage: "
    echo "  bash $0 <command> <cluster_name> <option>"
    echo ""
    echo "  尝试 'bash dst.sh <start|stop|restart|status|send|-r|rollback|-h|--help> <cluster_name> [option]'"
    echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
    echo ""
    echo "Commands:"
    echo "  status    查询存档（主世界）运行状态"
    echo "            用法： "
    echo "                bash $0 restart <cluster_name>"
    echo "            举例："
    echo "                bash $0 restart Cluster_1           重启开启存档 Cluster_1 的主世界和洞穴"
    exit 1
}

# 发送消息功能语法提示
_sendUsageTip(){
    echo "Usage: "
    echo "  bash $0 <command> <cluster_name> <option>"
    echo ""
    echo "  尝试 'bash dst.sh <start|stop|restart|status|send|-r|rollback|-h|--help> <cluster_name> [option]'"
    echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
    echo ""
    echo "Commands:"
    echo "  send      给世界和洞穴发送消息通知"
    echo "            用法："
    echo "                bash $0 send <cluster_name> [message]"
    echo "            举例："
    echo "                bash $0 send Cluster_1  '新增Mod，服务器将在下午重启!'  "
    exit 1
}

# 重置世界功能语法提示
_regenerateWorldUsageTip(){
    echo "Usage: "
    echo "  bash $0 <command> <cluster_name> <option>"
    echo ""
    echo "  尝试 'bash dst.sh <start|stop|restart|status|send|-r|rollback|-h|--help> <cluster_name> [option]'"
    echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
    echo ""
    echo "Commands:"
    echo "  -r        regenerateWorld 重置世界"
    echo "            用法： "
    echo "                bash $0 -r <cluster_name>"
    echo "            举例："
    echo "                bash $0 -r Cluster_1                  重置存档 Cluster_1   "
    exit 1
}

# 回档功能语法提示
_rollbackUsageTip(){
    echo "Usage: "
    echo "  bash $0 <command> <cluster_name> <option>"
    echo ""
    echo "  尝试 'bash dst.sh <start|stop|restart|status|send|-r|rollback|-h|--help> <cluster_name> [option]'"
    echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
    echo ""
    echo "Commands:"
    echo "  rollback  regenerateWorld 重置世界"
    echo "            用法："
    echo "                bash $0 rollback <cluster_name> [option]"
    echo "            举例："
    echo "                bash $0 rollback Cluster_1           回档 Cluster_1 默认 1 次 "
    echo "                bash $0 rollback Cluster_1 3         回档 Cluster_1 指定 3 次 "
    exit 1
}

####################################################
# 功能：检查进程是否存在
#
# 参数:
#   PS_NAME : 进程名称
# 返回值:
#      pid : 进程PID,如果不存在该进程则返回0
####################################################
_checkPid(){
  PS_NAME=$1
  ps_out=$(ps -ef | grep "${PS_NAME}" | grep -v 'grep' | grep -v "$0")
  result=$(echo "$ps_out" | grep "${PS_NAME}")
  echo "$result"
}

####################################################
# 功能：端口检测,如果存在则分配指定范围内随机端口
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
_checkPort(){
  PORT="$1"

  while lsof -i:"${PORT}" > /dev/null ;do
    PORT=$((RANDOM%$(( $RIGHT_VAL - $LEFT_VAL )) + $LEFT_VAL ))
  done

  echo "${PORT}"
}

###################################################
# 功能：读取ini配置文件信息
#
# 参数:
#    INI_FILE : 配置文件全路径名
#     SECTION : 配置文件中的节 配置文件中 [ ] 内的字段
#        ITEM : 对应key字段
#
# 返回值:
#      value : 对应key的value值
####################################################
_readINI(){
 INI_FILE=$1; SECTION=$2; ITEM=$3
 value=$(awk -F '=' '/\['"$SECTION"'\]/{a=1}a==1&&$1~/'"$ITEM"'/{print $2;exit}' "$INI_FILE")
 echo "${value}"
}

###################################################
# 功能：screen窗口管理，给指定窗口发送命令
#
# 参数:
#   SCREEN_NAME : $1 窗口名称
#           CMD : $2 窗口命令
####################################################
_screenMgr(){
  SCREEN_NAME="$1"
  CMD="$2"

  # 检查窗口名称是否存在，不存在则直接返回
  if [[ $(_checkPid "${SCREEN_NAME}") == "" ]] ; then
    echo "${SCREEN_NAME} 窗口不存在，无法发送命令：${CMD} 。"
    return
  fi

  # 给窗口发送命令并执行
  screen -x -S "${SCREEN_NAME}" -p 0 -X stuff "${CMD}"
  screen -x -S "${SCREEN_NAME}" -p 0 -X stuff $'\n'
}

##################################################
# 功能：读取存档的配置信息
#
# 参数:
#   CLUSTER_NAME : $1 存档名称
#
# 返回值:
#   NULL
##################################################
_readConfig(){
  local CLUSTER_NAME="$1"

  # 文件全路径
  cluster_ini="${CLUSTER_PATH}/${CLUSTER_NAME}/cluster.ini"
  master_ini="${CLUSTER_PATH}/${CLUSTER_NAME}/Master/server.ini"
  caves_ini="${CLUSTER_PATH}/${CLUSTER_NAME}/Caves/server.ini"

  # 世界的基本信息
  game_mode=$(_readINI "${cluster_ini}" "GAMEPLAY" "game_mode" |sed -e 's/^[ \t]*//g')
  max_players=$(_readINI "${cluster_ini}" "GAMEPLAY" "max_players" |sed -e 's/^[ \t]*//g')
  cluster_name=$(_readINI "${cluster_ini}" "NETWORK" "cluster_name" |sed -e 's/^[ \t]*//g')
  cluster_description=$(_readINI "${cluster_ini}" "NETWORK" "cluster_description" |sed -e 's/^[ \t]*//g')
  cluster_password=$(_readINI "${cluster_ini}" "NETWORK" "cluster_password" |sed -e 's/^[ \t]*//g')
  server_port=$(_readINI "${cluster_ini}" "SHARD" "master_port" |sed -e 's/^[ \t]*//g')
  master_port=$(_readINI "${master_ini}" "NETWORK" "server_port" |sed -e 's/^[ \t]*//g')
  caves_port=$(_readINI "${caves_ini}" "NETWORK" "server_port" |sed -e 's/^[ \t]*//g')
}

###################################################
# 功能：对存档的配置文件端口进行检查，如果端口被占用则重新分配端口
#      注：该方法依赖_readConfig()方法中产生的全局变量
#
# 参数:
#   CLUSTER_NAME : $1 存档名称
####################################################
_distributePort(){
  local CLUSTER_NAME=$1

  # 读取存档的部分配置信息
  _readConfig "$CLUSTER_NAME"

  # 检查端口占用情况,如果占用则分配新的端口
  server_port=$(_checkPort "${server_port}")
  master_port=$(_checkPort "${master_port}")
  caves_port=$(_checkPort "${caves_port}")

  # 将端口写入配置文件
  sed -i "s/\(^master_port.*\)/master_port = ${server_port}/g" "${cluster_ini}"
  sed -i "s/\(^server_port.*\)/server_port = ${master_port}/g" "${master_ini}"
  sed -i "s/\(^server_port.*\)/server_port = ${caves_port}/g" "${caves_ini}"
}

###################################################
# 功能：展示当前存档的配置信息 TODO 后续增加修改对应配置功能
#
# 参数:
#   CLUSTER_NAME : $1 存档名称
####################################################
_displayWorldInfo(){
  local CLUSTER_NAME="$1"
  # 读取配置信息
  _readConfig "${CLUSTER_NAME}"

  # 打印配置信息
  HOST_IP=$(curl -s ipinfo.io | grep ip|awk -F\" 'NR==1{print $4}')         # 云服公网IP
  connectCMD="c_connect(\"${HOST_IP}\", ${master_port}, \"${cluster_password}\")"
  echo ""
  echo "======================== 当前存档：[ ${CLUSTER_NAME} ] =========================="
  echo ""
  printf "%-25s %s\n" "世界名称:"    "${cluster_name}"
  printf "%-25s %s\n" "世界描述:"     "${cluster_description}"
  printf "%-25s %s\n" "最多玩家:" "${max_players}"
  printf "%-25s %s\n" "游戏模式:"   "${game_mode}"
  printf "%-25s %s\n" "互连端口:"   "${server_port}"
  printf "%-25s %s\n" "世界端口:"  "${master_port}"
  printf "%-25s %s\n" "洞穴端口:"   "${caves_port}"
  printf "%-25s %s\n" "直连命令:"   "${connectCMD}"
  echo ""
  echo "--------------------------------------------------------------------------------"
  echo ""
}

# 启动服务
func_start(){
    local CLUSTER_NAME=$1
    local OPTION=$2
    # 未指定主世界还是洞穴，则默认开启主世界和洞穴
    if [[ -z $2 ]]; then
      local MASTER_SCREEN_NAME="${CLUSTER_NAME}_Master"
      local CAVES_SCREEN_NAME="${CLUSTER_NAME}_Caves"

      # 查看是否存在存档名的窗口，只有不存在情况下才启动
      if [[ $(_checkPid "${CLUSTER_NAME}") == "" ]]; then
        # 1.检查端口占用情况并重新分配端口写入配置文件
        _distributePort "${CLUSTER_NAME}"

        # 2.展示世界配置信息
        _displayWorldInfo "${CLUSTER_NAME}"

        # 开启守护窗口
        screen -dmS "${MASTER_SCREEN_NAME}"
        screen -dmS "${CAVES_SCREEN_NAME}"

        # 启动主世界的窗口命令
        cmd_master=$"cd ${SCRIPT_DIR} && ./dontstarve_dedicated_server_nullrenderer_x64 -console -cluster ${CLUSTER_NAME} -shard Master$(printf \\r)";
        cmd_caves=$"cd ${SCRIPT_DIR} && ./dontstarve_dedicated_server_nullrenderer_x64 -console -cluster ${CLUSTER_NAME} -shard Caves$(printf \\r)";

        # 给窗口发送命令并执行
        screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd_master}"
        screen -x -S "${CAVES_SCREEN_NAME}" -p 0 -X stuff "${cmd_caves}"

        # 启动世界需要一定时间进行等待才能真正在客户端搜索到世界
        echo "游戏启动中..."
        _progress ${TIME_START_TIP}

        if [[ $? -ne 0 ]];then
          echo "${CLUSTER_NAME} 启动失败!"
        else
          echo "${CLUSTER_NAME} 启动成功!"
        screen -ls
        fi
      else
        echo "ERROR: ${CLUSTER_NAME} 已启动 [PID:${pid}]，本次启动失败！"
        screen -ls
        echo "----------------------------------------------------------------------------"
        exit 1
      fi
    # 指定开启主世界或者洞穴
    else
      SCREEN_NAME="${CLUSTER_NAME}_${OPTION}"
      if [[ $(_checkPid "${SCREEN_NAME}") == "" ]]; then
        # 开启守护进程
        screen -dmS "${SCREEN_NAME}"
        # 给窗口发送的命令
        cmd=$"cd ${SCRIPT_DIR} && ./dontstarve_dedicated_server_nullrenderer_x64 -console -cluster ${CLUSTER_NAME} -shard ${OPTION}$(printf \\r)";
        # 给窗口发送命令并执行
        screen -x -S "${SCREEN_NAME}" -p 0 -X stuff "${cmd}"

        # 等待10s
        echo "游戏启动中..."
        _progress 10

        if [[ $? -ne 0 ]];then
          echo "${SCREEN_NAME} 启动失败!"
        else
          echo "${SCREEN_NAME} 启动成功!"
        screen -ls
        fi

      else
        echo "ERROR: ${SCREEN_NAME} 已启动 [PID:${pid}]，本次启动失败！"
        screen -ls
        echo "----------------------------------------------------------------------------"
        exit 1
      fi
    fi
}

# 停止服务
func_stop(){
    local CLUSTER_NAME=$1
    local OPTION=$2
    # 未指定主世界还是洞穴，则默认关闭主世界和洞穴
    if [[ -z ${OPTION} ]]; then
      local MASTER_SCREEN_NAME="${CLUSTER_NAME}_Master"
      local CAVES_SCREEN_NAME="${CLUSTER_NAME}_Caves"
      local SCREEN_NAME_ARR=("${MASTER_SCREEN_NAME}" "${CAVES_SCREEN_NAME}")

      for screen_name in "${SCREEN_NAME_ARR[@]}";do
        # 只有世界在运行时候才会执行关闭
        if [[ $(_checkPid "${screen_name}") != "" ]]; then
          # 关闭前的提示信息命令
          cmd_msg="c_announce(\"${CLOSE_MSG}\")$(printf \\r)"
          # 关闭服务的命令
          cmd_close="c_shutdown(true)$(printf \\r)"
          # 退出窗口命令
          cmd_exit="exit$(printf \\r)"

          # 给服务器发送通知
          for i in {1..3}; do
            screen -x -S "${screen_name}" -p 0 -X stuff "${cmd_msg}"
          done

          # 倒计时回显提示
          echo "窗口：${screen_name} 服务即将关闭...预计${TIME_STOP_TIP}秒"
          _progress ${TIME_STOP_TIP}

          # 倒计时给服务器发送关闭命令
          screen -x -S "${screen_name}" -p 0 -X stuff "${cmd_close}"

          # 最后退出screen窗口
          echo "服务关闭成功，等待窗口退出...预计${TIME_EXIT_SCREEN}秒"
          _progress ${TIME_EXIT_SCREEN}

          screen -x -S "${screen_name}" -p 0 -X stuff "${cmd_exit}"
          echo "窗口退出完毕。"
          screen -ls
        else
          echo "WARMING:窗口：${screen_name} 未运行，无需再次关闭！"
        fi
      done
    # 指定关闭主世界或者洞穴
    else
      local SCREEN_NAME="${CLUSTER_NAME}_${OPTION}"
      # 只有窗口存在时才关闭
      if [[ $(_checkPid "${SCREEN_NAME}") != "" ]]; then
        # 关闭前的提示信息命令
        cmd_msg="c_announce(\"${CLOSE_MSG}\")$(printf \\r)"
        # 关闭服务的命令
        cmd_close="c_shutdown(true)$(printf \\r)"
        # 退出窗口命令
        cmd_exit="exit$(printf \\r)"

        # 给服务器发送通知
        for i in {1..3}; do
          screen -x -S "${SCREEN_NAME}" -p 0 -X stuff "${cmd_msg}"
        done

        # 倒计时回显提示
        echo "窗口：${screen_name} 服务即将关闭...预计${TIME_STOP_TIP}秒"
        _progress ${TIME_STOP_TIP}

        # 倒计时给服务器发送关闭命令
        screen -x -S "${SCREEN_NAME}" -p 0 -X stuff "${cmd_close}"

        # 最后退出screen窗口
        echo "服务关闭成功，等待窗口退出...预计${TIME_EXIT_SCREEN}秒"
        _progress ${TIME_EXIT_SCREEN}

        screen -x -S "${SCREEN_NAME}" -p 0 -X stuff "${cmd_exit}"
        screen -ls
      else
        echo "WARMING:窗口：${SCREEN_NAME} 未运行，无需再次关闭！"
      fi
    fi
}

# 重启服务
func_restart(){
    local CLUSTER_NAME=$1
    func_stop "${CLUSTER_NAME}"
    func_start "${CLUSTER_NAME}"
}

# 查询状态
func_status(){
    app_name=$1

    if [[ $(_checkPid "${app_name}") != "" ]] ;then
      echo ""
	    echo "${app_name} 正在运行. "
	    _displayWorldInfo "${app_name}"
    else
	    echo "${app_name} 未运行."
    fi
}

# 发送消息
func_sendMsg(){
  CLUSTER_NAME=$1
  MSG="${OPTION}"

  # 只有主世界存在才会发送消息（不支持仅给洞穴发送消息）
  if [[ $(_checkPid "${CLUSTER_NAME}") != "" ]]; then
    # 回显世界信息
    _displayWorldInfo "${CLUSTER_NAME}"

    MASTER_SCREEN_NAME="${CLUSTER_NAME}_Master"
    cmd="c_announce(\"${MSG}\")$(printf \\r)"

    screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd}"
    echo "消息发送成功！"
  else
    echo "ERROR: ${CLUSTER_NAME} 未启动，消息发送失败！"
  fi
}

# 重置世界
func_regenerateWorld(){
  CLUSTER_NAME=$1

  # 先读取存档信息
  _displayWorldInfo "${CLUSTER_NAME}"

  # 重置世界需要二次确认
  read -r -p "该命令将会重置世界，确认是否继续？ [Y/n] " input

  case $input in
    [yY][eE][sS]|[yY])
    # 只有主世界存在才能重置世界
    if [[ $(_checkPid "${CLUSTER_NAME}") != "" ]]; then
      MASTER_SCREEN_NAME="${CLUSTER_NAME}_Master"

      # 重置前提示
      cmd_rollback_tips="c_announce(\"${REGENERATE_WORLD_MSG}\")$(printf \\r)"
      for i in {1..3};do
        screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd_rollback_tips}"
      done

      # 回档倒计时
      echo "服务器即将重置...预计${TIME_REGENERATE_WORLD_TIP}秒"
      _progress ${TIME_REGENERATE_WORLD_TIP}

      # 重置命令
      cmd="c_regenerateworld()$(printf \\r)"
      screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd}"
      echo "存档 ${CLUSTER_NAME} 已重置！"
    else
      echo "ERROR: ${CLUSTER_NAME} 未启动，无法重置！"
    fi
      ;;
    [nN][oO]|[nN])
      echo "已取消存档 ${CLUSTER_NAME} 的重置世界操作，程序退出"
      exit 0
      ;;
    *)
        echo "Invalid input..."
        exit 1
        ;;
  esac
}

# 回档
func_rollback(){
  CLUSTER_NAME=$1
  COUNT=${OPTION}

  if [ -z "${COUNT}" ]; then
      COUNT=1
  fi

  # 只有主世界存在才能重置世界
  if [[ $(_checkPid "${CLUSTER_NAME}") != "" ]]; then
    MASTER_SCREEN_NAME="${CLUSTER_NAME}_Master"
    cmd="c_rollback(${COUNT})$(printf \\r)"

    # 回档前输出世界信息回显
    _displayWorldInfo "${CLUSTER_NAME}"

    # 回档前提示
    cmd_rollback_tips="c_announce(\"${ROLLBACK_MSG}\")$(printf \\r)"
    for i in {1..3};do
      screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd_rollback_tips}"
    done

    # 回档进度条
    echo "服务期即将回档...预计${TIME_ROLLBACK_TIP}秒"
    _progress ${TIME_ROLLBACK_TIP}

    screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd}"
    echo "存档 ${CLUSTER_NAME} 已回档，回档次数: ${COUNT} ！"

  else
    echo "ERROR: ${CLUSTER_NAME} 未启动，无法回档！"
  fi
}

# 参数-h或者--help给出完整语法提示
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  _usageTip
fi

# 没有位置参数给出简短语法提示
if [[ $# == 0 ]];then
  _simpleUsageTip
fi

# 存档目录不存在提示
if [[ -n ${CLUSTER_NAME} ]] && [[ ! -d "${CLUSTER_PATH}/${CLUSTER_NAME}" ]];then
  echo "ERROR: ${CLUSTER_NAME} 存档目录不存在！"
  _simpleUsageTip
fi

#### 命令判断  ####
case "${COMMAND}" in
	'start')
	  # start 后面参数错误提示
	  if [[ -z "${CLUSTER_NAME}" ]];then
	    _startUsageTip
	  fi

	  if [[ -z "${OPTION}" ]]; then
	    func_start "${CLUSTER_NAME}"
	  else
	    func_start "${CLUSTER_NAME}" "${OPTION}"
	  fi
		;;
	'stop')
	  # stop 后面参数错误提示
	  if [[ -z "${CLUSTER_NAME}" ]];then
	    _stopUsageTip
	  fi

	  if [[ -z "${OPTION}" ]]; then
	    func_stop "${CLUSTER_NAME}"
	  else
	    func_stop "${CLUSTER_NAME}" "${OPTION}"
	  fi
		;;
	'restart')
	  # restart 后面参数错误提示
	  if [[ -z "${CLUSTER_NAME}" ]];then
	    _restartUsageTip
	  fi

		func_restart "${CLUSTER_NAME}"
		;;
	'status')
	  # status 后面参数错误提示
	  if [[ -z "${CLUSTER_NAME}" ]];then
	    _statusUsageTip
	  fi

		func_status "${CLUSTER_NAME}"
		;;
  'send')
  	# send 命令必须携带消息，否则给出提示
	  if [[ -z "${CLUSTER_NAME}" ]] || [[ -z "${OPTION}" ]]; then
	    _sendUsageTip
	  fi
  	func_sendMsg "${CLUSTER_NAME}"
  	;;
  '-r')
	  # -r 后面参数错误提示
	  if [[ -z "${CLUSTER_NAME}" ]];then
	    _regenerateWorldUsageTip
	  fi

    func_regenerateWorld "${CLUSTER_NAME}"
    ;;
  'rollback')
	  # rollback 后面参数错误提示
	  if [[ -z "${CLUSTER_NAME}" ]];then
	    _rollbackUsageTip
	  fi

  	func_rollback "${CLUSTER_NAME}"
  	;;
	*)
		_simpleUsageTip
		exit 1
esac
exit 0




