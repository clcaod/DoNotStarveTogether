#!/bin/bash
#
# 饥荒专服管理系统
#
# Author: tough
# 2022-07-02
#
# GitHub链接：https://github.com/clcaod/DoNotStarveTogether.git
#
# Linux后台下载命令： wget https://raw.githubusercontent.com/clcaod/DoNotStarveTogether/main/DedicatedServerManageScript/dst.sh
#

#-------------------------------------------配置区----------------------------------------------------------------------#

# 目录路径配置 ###########################################################################################################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"      # 使用这条语句需要脚本放置在饥荒安装目录的bin目录下
#SCRIPT_DIR="$(cd ~/dstserver/bin64/ && pwd)"                      # 使用这条语句需要替换为实际安装目录

CLUSTER_PATH="$(cd ~/.klei/DoNotStarveTogether/ && pwd)"            # 饥荒默认存档目录，如果不正确需要修改

LOCAL_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"  # 本脚本所在目录

# 自动更新功能的配置项
CRONTAB_EXP="0 */3 * * *"                                  # 定时任务表达式 分 时 天 月 星期 ，当前含义：每隔3小时进行一次自动更新
UPDATE_PATH="${LOCAL_SCRIPT_DIR}/updateDST"
LOG_FILE="${UPDATE_PATH}/update.log"
CLUSTER_LIST_FILE="${UPDATE_PATH}/clusterList.txt"
STEAMCMD_PATH="$(cd ~/Steam/ && pwd)"                               # steamcmd安装的目录

# 游戏内互动功能
ROBOT_LOG_FILE="${UPDATE_PATH}/robot.log"

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

# 简短的语法提示,为了提高代码复用性，将方法内exit命令移除，调用该方法后需要手动执行exit 1
_simpleUsageTip(){
  echo "Usage: "
  echo "  bash $0 <command> <cluster_name> <option>"
  echo ""
  echo "  尝试 'bash dst.sh <start|stop|restart|status|send|ban｜-r|rollback|robot|update|-h|--help> <cluster_name|enable|disable> [option]'"
  echo "  尝试 'bash dst.sh -h 或者 bash dst.sh --help 查看更多信息"
}

# 完整的语法提示
_usageTip(){
  _simpleUsageTip
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
  echo "  ban      让世界封禁一个玩家"
  echo "            用法："
  echo "                bash $0 ban <cluster_name> [player_name]"
  echo "            举例："
  echo "                bash $0 ban Cluster_1  'KU_zePBhE0b'  "
  echo ""
  echo "  -r        regenerateWorld 重置世界"
  echo "            用法： "
  echo "                bash $0 -r <cluster_name>"
  echo "            举例："
  echo "                bash $0 -r Cluster_1                  重置存档 Cluster_1   "
  echo ""
  echo "  rollback  世界回档"
  echo "            用法："
  echo "                bash $0 rollback <cluster_name> [option]"
  echo "            举例："
  echo "                bash $0 rollback Cluster_1           回档 Cluster_1 默认 1 次 "
  echo "                bash $0 rollback Cluster_1 3         回档 Cluster_1 指定 3 次 "
  echo ""
  echo "  update    服务器更新,启用后之后启动的存档将会在更新后自动重启"
  echo "            修改脚本配置区变量 'CRONTAB_EXP' 可配置定时更新时间"
  echo "            用法："
  echo "                bash $0 update <enable|disable>"
  echo "            举例："
  echo "                bash $0 update                       手动尝试执行更新 "
  echo "                bash $0 update enable                启动自动更新 "
  echo "                bash $0 update disable               关闭自动更新 "
  echo ""
  echo "Cluster_name:"
  echo "            存档名称，默认格式 Cluster_# ,#为数字1,2,...n"
  echo "            存档存在时正常执行，存档不存在时候启动则会在默认目录创建存档目录"
  echo ""
  echo "Options:"
  echo "  Master      需搭配命令 start|stop 使用，用于指定世界"
  echo "  Caves       需搭配命令 start|stop 使用，用于指定洞穴"
  echo "  Message     需搭配命令 send 使用，为字符串格式，给服务器发送的通知内容"
  echo "  count       需搭配命令 rollback 使用，为数字格式，指定回档的次数"
  echo "  player_name 需搭配命令 ban 使用，对该玩家进行封禁"
  exit 1
}

# 开启世界功能语法提示
_startUsageTip(){
  _simpleUsageTip
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
  _simpleUsageTip
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
  _simpleUsageTip
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
  _simpleUsageTip
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
  _simpleUsageTip
  echo ""
  echo "Commands:"
  echo "  send      给世界和洞穴发送消息通知"
  echo "            用法："
  echo "                bash $0 send <cluster_name> [message]"
  echo "            举例："
  echo "                bash $0 send Cluster_1  '新增Mod，服务器将在下午重启!'  "
  exit 1
}

# 发送消息功能语法提示
_banUsageTip(){
  _simpleUsageTip
  echo ""
  echo "Commands:"
  echo "  ban      让世界封禁一个玩家"
  echo "            用法："
  echo "                bash $0 ban <cluster_name> [player_name]"
  echo "            举例："
  echo "                bash $0 ban Cluster_1  'KU_zePBhE0b'  "
  exit 1
}

# 重置世界功能语法提示
_regenerateWorldUsageTip(){
  _simpleUsageTip
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
  _simpleUsageTip
  echo ""
  echo "Commands:"
  echo "  rollback  世界回档"
  echo "            用法："
  echo "                bash $0 rollback <cluster_name> [option]"
  echo "            举例："
  echo "                bash $0 rollback Cluster_1           回档 Cluster_1 默认 1 次 "
  echo "                bash $0 rollback Cluster_1 3         回档 Cluster_1 指定 3 次 "
  exit 1
}

# 游戏内自回复提示
_robotUsageTip(){
  _simpleUsageTip
  echo ""
  echo "Commands:"
  echo "  robot     对存档开启自查询功能"
  echo "            用法："
  echo "                bash $0 robot <cluster_name> [enable|disable]"
  echo "            举例："
  echo "                bash $0 robot Cluster_1                 对 Cluster_1 存档开启自查功能"
  echo "                bash $0 robot Cluster_1 enable          对 Cluster_1 存档后台开启自查功能"
  echo "                bash $0 robot Cluster_1 disable         对 Cluster_1 存档后台关闭自查功能"
  exit 1
}

# 更新功能语法提示
_updateUsageTip(){
  _simpleUsageTip
  echo ""
  echo "Commands:"
  echo "  update    服务器更新,启用后之后启动的存档将会在更新后自动重启"
  echo "            修改脚本配置区变量 'CRONTAB_EXP' 可配置定时更新时间"
  echo "            用法："
  echo "                bash $0 update <enable|disable>"
  echo "            举例："
  echo "                bash $0 update                       手动尝试执行更新 "
  echo "                bash $0 update enable                启动自动更新 "
  echo "                bash $0 update disable               关闭自动更新 "
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

# 校验文件是否存在，不存在则返回0，存在返回1
_checkFile(){
  file=$1
  if [ -f "$file" ]; then
    echo 1
  else
    echo 0
  fi
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

  # 读取服务器配置文件
  if [ "$(_checkFile "${cluster_ini}")" == 0 ]; then
    unset game_mode
    unset max_players
    unset cluster_name
    unset cluster_description
    unset cluster_password
    unset server_port
  else
    game_mode=$(_readINI "${cluster_ini}" "GAMEPLAY" "game_mode" |sed -e 's/^[ \t]*//g')
    max_players=$(_readINI "${cluster_ini}" "GAMEPLAY" "max_players" |sed -e 's/^[ \t]*//g')
    cluster_name=$(_readINI "${cluster_ini}" "NETWORK" "cluster_name" |sed -e 's/^[ \t]*//g')
    cluster_description=$(_readINI "${cluster_ini}" "NETWORK" "cluster_description" |sed -e 's/^[ \t]*//g')
    cluster_password=$(_readINI "${cluster_ini}" "NETWORK" "cluster_password" |sed -e 's/^[ \t]*//g')
    server_port=$(_readINI "${cluster_ini}" "SHARD" "master_port" |sed -e 's/^[ \t]*//g')
  fi

  # 读取世界配置文件
  if [ "$(_checkFile "${master_ini}")" == 0 ]; then
    unset master_port
  else
    master_port=$(_readINI "${master_ini}" "NETWORK" "server_port" |sed -e 's/^[ \t]*//g')
  fi

  # 读取洞穴配置文件
  if [ "$(_checkFile "${caves_ini}")" == 0 ]; then
    unset caves_port
  else
    caves_port=$(_readINI "${caves_ini}" "NETWORK" "server_port" |sed -e 's/^[ \t]*//g')
  fi


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

# 列举目录,仅名称包含 Cluster 的目录会列举
_listDir(){
  DIR_PATH=$1
  dir_list=$(ls -l "${DIR_PATH}"|awk '/^d/ {print $NF}'|grep Cluster)
  echo "$dir_list"
}

# 日志打印格式化
_printLog(){
  content=$1
  log_file=$2
  echo "[$(date '+%Y-%m-%d %H:%M:%S')]: ${content}" >> ${log_file}
}

# 格式化输出
_printfStatus(){
  # 位置参数
  CLUSTER_NAME="$1"

  # 是否开启自动更新功能
  isEnable="已开启"
  result=$(crontab -l 2>/dev/null| grep -c "$0")
  if [ "${result}" == 0 ]; then
    isEnable="未启动"
    printf "自动更新功能: %s\n" "${isEnable}"
  else
    printf "自动更新功能: %s\n" "${isEnable}"
    printf "更新日志: %s\n" "${LOG_FILE}"
  fi

  # 表头字段
  title1="存档名称"
  title2="游戏模式"
  title3="最大人数"
  title4="运行状态"
  title5="更新自启动"
  title6="自查功能"
  title7="世界名称"

  # 打印表头
  printf "%-10s\t %-10s\t %-10s\t %-10s\t %-10s\t %-10s\t %s\n" $title1 $title2 $title3 $title4 $title5 $title6 $title7
  # 数据打印
  cluster_arr=($(_listDir "${CLUSTER_PATH}"))
  if [ -n "${CLUSTER_NAME}" ]; then
      cluster_arr=(${CLUSTER_NAME})
  fi
  for dir in "${cluster_arr[@]}";do
    _readConfig $dir

    # 运行状态判断
    status="未运行"
    if [ "$(_checkPid "${dir}")" != "" ]; then
      status="正在运行"
    fi

    # 更新自启动
    autoStart="FALSE"
    if [ -f "${CLUSTER_LIST_FILE}" ] && [ $(cat "${CLUSTER_LIST_FILE}" | grep -c "${dir}") != 0 ]; then
      autoStart="TRUE"
    fi

    # 自查功能是否启动
    isRobotEnable="未启动"
    if [[ "$(_checkPid "${dir}_ROBOT")" != "" ]]; then
      isRobotEnable="已启动"
    fi

    # 打印数据
    printf "%-10s\t %-10s\t %-10s\t %-10s\t %-10s\t %-10s\t %s\n" "$dir" "$game_mode" "$max_players" "$status" "$autoStart" "$isRobotEnable" "$cluster_name"
  done
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
      if [[ $(_checkPid "${CLUSTER_NAME}_Master") == "" ]]; then
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
          echo ""
          echo "  尝试  bash dst.sh status 可查看所有存档状态信息"
        else
          # 启动世界追加到更新自动重启列表中
          if [ -f "${CLUSTER_LIST_FILE}" ] && [ "$(grep -wc "${CLUSTER_NAME}" < "${CLUSTER_LIST_FILE}")" == 0 ]; then
              echo "${CLUSTER_NAME}" >> "${CLUSTER_LIST_FILE}"
          fi

          echo "${CLUSTER_NAME} 启动成功!"
          echo ""
          echo "使用命令: bash $0 status 可查看所有存档状态信息"
        fi
      else
        echo "ERROR: ${CLUSTER_NAME} 已启动，请勿重复启动！"
        echo "使用命令: bash $0 status 可查看所有存档状态信息"
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
          echo "  尝试  bash dst.sh status 可查看所有存档状态信息"
        else
          echo "${SCREEN_NAME} 启动成功!"
          # 启动世界追加到更新自动重启列表中
          if [ -f "${CLUSTER_LIST_FILE}" ] && [ "$(grep -wc "${CLUSTER_NAME}" < "${CLUSTER_LIST_FILE}")" == 0 ]; then
              echo "${CLUSTER_NAME}" >> "${CLUSTER_LIST_FILE}"
          fi
          echo ""
          echo "  尝试  bash dst.sh status 可查看所有存档状态信息"
        fi

      else
        echo "ERROR: ${SCREEN_NAME} 已启动，请勿重复启动！"
        echo "使用命令: bash $0 status 可查看所有存档状态信息"
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
          echo "窗口：${screen_name} "
          echo "服务即将关闭...预计${TIME_STOP_TIP}秒"
          _progress ${TIME_STOP_TIP}
          echo "服务关闭成功!"
          # 倒计时给服务器发送关闭命令
          screen -x -S "${screen_name}" -p 0 -X stuff "${cmd_close}"

          # 最后退出screen窗口
          echo "等待窗口退出...预计${TIME_EXIT_SCREEN}秒"
          _progress ${TIME_EXIT_SCREEN}

          screen -x -S "${screen_name}" -p 0 -X stuff "${cmd_exit}"
          echo "窗口退出完毕。"

        else
          echo "WARMING:窗口：${screen_name} 未运行，无需再次关闭！"
        fi
      done
      # 移除更新自动启动列表
      sed -i s/"${CLUSTER_NAME}"//g "${CLUSTER_LIST_FILE}"

      echo ""
      echo "使用命令: bash $0 status 可查看所有存档状态信息"

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
        echo "窗口：${screen_name} "
        echo "服务即将关闭...预计${TIME_STOP_TIP}秒"
        _progress ${TIME_STOP_TIP}

        # 倒计时给服务器发送关闭命令
        screen -x -S "${SCREEN_NAME}" -p 0 -X stuff "${cmd_close}"

        # 最后退出screen窗口
        echo "服务关闭成功!"
        echo "等待窗口退出...预计${TIME_EXIT_SCREEN}秒"
        _progress ${TIME_EXIT_SCREEN}

        screen -x -S "${SCREEN_NAME}" -p 0 -X stuff "${cmd_exit}"
        echo "窗口退出完毕。"
        echo ""
        echo "使用命令: bash $0 status 可查看所有存档状态信息"
      else
        echo "WARMING:窗口：${SCREEN_NAME} 未运行，无需再次关闭！"
        echo ""
        echo "使用命令: bash $0 status 可查看所有存档状态信息"
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

    # 不传参则查询所有已有存档状态信息
    if [[ -z "${app_name}" ]]; then
      _printfStatus
    else
      _printfStatus $app_name
    fi
}

# 发送消息
func_sendMsg(){
  CLUSTER_NAME=$1
  MSG=$2

  # 只有主世界存在才会发送消息（不支持仅给洞穴发送消息）
  if [[ $(_checkPid "${CLUSTER_NAME}") != "" ]]; then

    MASTER_SCREEN_NAME="${CLUSTER_NAME}_Master"
    cmd="c_announce(\"${MSG}\")$(printf \\r)"

    screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd}"
    echo "消息发送成功！"
  else
    echo "ERROR: ${CLUSTER_NAME} 未启动，消息发送失败！"
  fi
}

# 禁止玩家
func_ban(){
    CLUSTER_NAME=$1
    PLAYER_NAME="${OPTION}"

    # 只有主世界存在才会发送消息（不支持仅给洞穴发送消息）
    if [[ $(_checkPid "${CLUSTER_NAME}") != "" ]]; then

      MASTER_SCREEN_NAME="${CLUSTER_NAME}_Master"
      cmd="TheNet:Ban(\"${PLAYER_NAME}\")$(printf \\r)"

      screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd}"
      echo "玩家 ${PLAYER_NAME} 已被禁止加入游戏！"
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

      # 重置倒计时
      echo "服务器即将重置...预计${TIME_REGENERATE_WORLD_TIP}秒"
      _progress ${TIME_REGENERATE_WORLD_TIP}

      # 重置命令
      cmd="c_regenerateworld()$(printf \\r)"
      screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd}"
      echo "存档 ${CLUSTER_NAME} 已重置！"
      echo ""
      echo "使用命令: bash $0 status 可查看所有存档状态信息"
    else
      echo "ERROR: ${CLUSTER_NAME} 未启动，无法重置！"
      echo ""
      echo "使用命令: bash $0 status 可查看所有存档状态信息"
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

  # 校验是否为数字
  if [ -n "${COUNT}" ] && [ -z "$(echo "${COUNT}"|sed -n '/[0-9][0-9]*$/p')" ]; then
    echo "ERROR: 回档次数需要为数字!"
    _rollbackUsageTip
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
    echo "服务器即将回档...预计${TIME_ROLLBACK_TIP}秒"
    _progress ${TIME_ROLLBACK_TIP}

    screen -x -S "${MASTER_SCREEN_NAME}" -p 0 -X stuff "${cmd}"
    echo "存档 ${CLUSTER_NAME} 已回档，回档次数: ${COUNT} "

    echo ""
    echo "使用命令: bash $0 status 可查看所有存档状态信息"

  else
    echo "ERROR: ${CLUSTER_NAME} 未启动，无法回档！"

    echo ""
    echo "使用命令: bash $0 status 可查看所有存档状态信息"
  fi
}

# 自动更新
func_update(){
  # update 命令的位置参数特殊，第二个参数 CLUSTER_NAME 实际为状态选项 enable|disable
  STATUS=${CLUSTER_NAME}

  # 如果STATUS为空则执行后面的更细，如果带参数则增加｜删除定时任务
  if [ -z "${STATUS}" ]; then
    # 函数没有位置参数时执行更新
    if [ ! -d "$UPDATE_PATH" ]; then
      mkdir "$UPDATE_PATH"
    fi

    CLUSTER_LIST_ARRAY=($(cat "${CLUSTER_LIST_FILE}"))

    # 不带参数则直接执行更新命令
    lastTime_version=$(cat "${SCRIPT_DIR}"/../version.txt)
    "${STEAMCMD_PATH}"/steamcmd.sh +force_install_dir "${SCRIPT_DIR}"/../ +login anonymous +app_update 343050 +quit
    current_version=$(cat "${SCRIPT_DIR}"/../version.txt)

    # 检测到有更新则对设置好的存档进行重启
    if [[ "${lastTime_version}" != "${current_version}"  ]];then
      for APP_NAME in "${CLUSTER_LIST_ARRAY[@]}" ;do
        bash "$0" restart "${APP_NAME}"
        echo "[ $(date '+%Y-%m-%d %H:%M:%S') ] 检测到版本更新，存档 ${APP_NAME} 已重启，旧版本号：${lastTime_version}  新版本号：${current_version}" >> "${LOG_FILE}"
      done
      echo "检测到新版本，版本更新。查看更新日志命令: cat ${LOG_FILE}"
    else
      echo "版本已是最新版本！"
    fi
  else
    cronStr="${CRONTAB_EXP} bash ${LOCAL_SCRIPT_DIR}/$0 update"

    # 存在参数执行自动更细开关设置
    if [ enable == "${STATUS}" ]; then
      # 开启自动更新增加重启列表
      touch "${CLUSTER_LIST_FILE}"
      touch "${LOG_FILE}"
      # 写入定时任务
      # 如果已存在定时任务不再重复添加
      result=$(crontab -l 2>/dev/null | grep "$0")
      if [ "${result}" == "" ]; then
        # 读取已存在的定时任务数量
        cron_count=$(crontab -l 2>/dev/null | wc -l)
        if [ "${cron_count}" != 0 ]; then
          crontab -l > conf && echo "${cronStr}" >> conf && crontab conf && rm -f conf
        else
          echo "${cronStr}" >> conf && crontab conf && rm -f conf
        fi

        # 执行完显示配置的定时任务
        echo "自动更新启动成功！修改自动更新频次请修改本脚本配置区：CRONTAB_EXP=\"${CRONTAB_EXP}\""
        echo ""
        echo "使用命令: bash $0 status 可查看所有存档状态信息"
      else
        echo "ERROR：自动更新功能已启动，请勿重复启动！"
        echo ""
        echo "使用命令: bash $0 status 可查看所有存档状态信息"
        exit 1
      fi
    elif [ disable == "${STATUS}" ];then
      # 移除文件
      rm -f "${CLUSTER_LIST_FILE}"
      # 无任务则直接退出
      if [ "$(crontab -l | grep -c "$0")" == 0 ]; then
          echo "ERROR:自动更新功能未启动,请勿重复关闭！"
          echo ""
          echo "使用命令: bash $0 status 可查看所有存档状态信息"
          exit 1
      fi
      # 关闭定时任务,如果除了本脚本无其他定时任务则清空，如果有则导出再过滤
      dst_cron_count=$(crontab -l | grep -vc "$0")
      if [ "${dst_cron_count}" == 0 ]; then
        crontab -r
      else
        crontab -l | grep -v "$0" >> conf && crontab conf && rm -f conf
      fi

      # 执行完显示配置的定时任务
      echo "SUCCESS:自动更新已关闭!"
      echo ""
      echo "使用命令: bash $0 status 可查看所有存档状态信息"
    else
      # 其他情况给出提示
      _updateUsageTip
    fi
  fi
}

# 游戏内聊天互动
func_robot(){
  # 存档目录
  CLUSTER_NAME=$1
  # 聊天文件
  chat_file="${CLUSTER_PATH}/${CLUSTER_NAME}/Master/server_chat_log.txt"

  # 聊天文件判断
  if [ ! -f "${chat_file}" ];then
    echo "文件不存在:${chat_file}"
    exit 1
  fi

  # 读取配置信息
  _readConfig "${CLUSTER_NAME}"

  # 打印配置信息
  HOST_IP=$(curl -s ipinfo.io | grep ip|awk -F\" 'NR==1{print $4}')         # 云服公网IP
  connectCMD="c_connect(\"${HOST_IP}\", ${master_port}, \"${cluster_password}\")"

  # 游戏公告
  time=$(date '+%Y-%m-%d %H:%M:%S')
  echo "存档 ${CLUSTER_NAME} 已开启自查服务。"
  echo "发送游戏公告..."
  func_sendMsg "${CLUSTER_NAME}" "当前时间:${time}"
  func_sendMsg "${CLUSTER_NAME}" "本房间已开启自查服务(测试阶段)，输入「@时间」「@XX天气」获取对应信息。"
  func_sendMsg "${CLUSTER_NAME}" "房间直连命令: ${connectCMD}"
  echo "等待玩家自查..."

  # 文件md5状态记录
  preview_md5="$(find "${chat_file}"|xargs md5sum |awk '{print $1}')"

  while true;do
    # 根据文件的md5值判断文件是否有进行修改
    current_md5="$(find "${chat_file}"|xargs md5sum |awk '{print $1}')"
    if [[ "${current_md5}" != "${preview_md5}" ]];then
      content=$(tail -1 "${chat_file}" | awk -F@ '{print $2}' |sed 's/[[:space:]]//g')
      preview_md5="${current_md5}"

      # 功能1：查询时间
      if [[  "${content}" =~ "时间"  ]];then
        time=$(date '+%Y-%m-%d %H:%M:%S')
        feed_back="当前时间:${time}"
        func_sendMsg "${CLUSTER_NAME}" "${feed_back}"
        echo "存档 ${CLUSTER_NAME} 互动 「@查询时间」"
        _printLog "检测到存档 ${CLUSTER_NAME} 互动 「@查询时间」,回馈内容:${feed_back}" "${ROBOT_LOG_FILE}"

      fi

      # 功能2：查询天气
      if [[ "$content" =~ "天气" ]];then
        # 查询天气的URL前缀
        url_pre="http://www.weather.com.cn/data/cityinfo"

        city_name=${content//天气/}
        # 根据列表文件获取cityId
        cityListUrl="https://raw.githubusercontent.com/clcaod/DoNotStarveTogether/main/DedicatedServerManageScript/cityList.txt"
        if [ ! -f "cityList.txt" ]; then
            for (( i = 0; i < 5; i++ )); do
                wget ${cityListUrl} >> /dev/null
                if [ -f "cityList.txt" ]; then
                  _printLog "加载cityList.txt文件成功" "${ROBOT_LOG_FILE}"
                  break
                fi
            done
            if [ ! -f "cityList.txt" ]; then
              echo "多次尝试加载城市ID列表失败，请稍后重试"
              ehco "自查服务启动失败"
              _printLog "多次尝试加载城市ID列表失败,本次启动自查服务失败" "${ROBOT_LOG_FILE}"
              exit 1
            fi
        fi

        cityId=$(grep "=${city_name}$" cityList.txt |awk -F= '{print $1}')
        echo "存档 ${CLUSTER_NAME} 互动 「@查询天气」, 读取城市名:${city_name}, 城市ID:${cityId}"
        _printLog "检测到存档 ${CLUSTER_NAME} 互动 「@查询天气」, 读取城市名:${city_name}, 城市ID:${cityId}" "${ROBOT_LOG_FILE}"

        if [ -z "${cityId}"  ];then
          feed_back="未匹配到当前城市的ID呢"
          func_sendMsg "${CLUSTER_NAME}" "${feed_back}"
          echo "查询城市失败,未匹配到当前城市的ID"
          _printLog "查询城市失败，回馈内容:${feed_back}" "${ROBOT_LOG_FILE}"
        else
          # 完整的url
          url="${url_pre}/${cityId}.html"

          # 获取json格式内容
          # {"weatherinfo":{"city":"深圳","cityid":"101280601","temp1":"24℃","temp2":"30℃","weather":"阵雨转大雨","img1":"n3.gif","img2":"d9.gif","ptime":"18:00"}}
          weather_json=$(curl "${url}")

          echo "请求网址 「${url}」返回的 json 数据 「${weather_json}」"
          _printLog "请求网址 「${url}」返回的 json 数据 「${weather_json}」" "${ROBOT_LOG_FILE}"

          # 解析
          temp1=$(echo "${weather_json}" |sed 's/,/\n/g' | grep temp1 |sed 's/"//g'|awk -F: '{print $2}')
          temp2=$(echo "${weather_json}" |sed 's/,/\n/g' | grep temp2 |sed 's/"//g'|awk -F: '{print $2}')
          weather=$(echo "${weather_json}" |sed 's/,/\n/g' | grep '"weather"' |sed 's/"//g'|awk -F: '{print $2}')

          echo "解析json数据: temp1=${temp1}, temp2=${temp2}, weather=${weather}"
          _printLog "解析json数据: temp1=${temp1}, temp2=${temp2}, weather=${weather}" "${ROBOT_LOG_FILE}"
          # 给服务器发送消息
          if [ -n "${temp1}" ] && [ -n "${temp2}" ] && [ -n "${weather}" ]; then
            feed_back="${city_name}今天${weather},最低温度${temp1},最高温度${temp2}"
            func_sendMsg "${CLUSTER_NAME}" "${feed_back}"
            echo "查询${content}成功,返回内容:${feed_back}"
            _printLog "查询${content}成功,返回内容:${feed_back}" "${ROBOT_LOG_FILE}"
          else
            feed_back="未匹配到当前城市的ID呢"
            echo "解析json数据存在空值!"
            _printLog "解析json数据存在空值，反馈内容:${feed_back}" "${ROBOT_LOG_FILE}"
            func_sendMsg "${CLUSTER_NAME}" "${feed_back}"
          fi
        fi
      fi

    fi
  done
}

# 游戏内聊天互动开关
func_robotSwitch(){
  CLUSTER_NAME=$1
  OPTION=$2

  ROBOT_SCREEN_NAME="${CLUSTER_NAME}_ROBOT"

  # OPTION为 enable|disable 其他则给出错误提示
  if [[ $(_checkPid "${CLUSTER_NAME}") != "" ]]; then
    # 启后台自查功能
    if [ "${OPTION}" == "enable" ]; then
      # 开启守护窗口
      screen -dmS "${ROBOT_SCREEN_NAME}"
      cmd="bash $0 robot ${CLUSTER_NAME} $(printf \\r)"
      screen -x -S "${ROBOT_SCREEN_NAME}" -p 0 -X stuff "${cmd}"
      echo "存档 ${CLUSTER_NAME} 聊天互动功能已后台启动"
      _printLog "存档 ${CLUSTER_NAME} 聊天互动功能已后台启动" "${ROBOT_LOG_FILE}"

      echo ""
      echo "使用命令: bash $0 status 可查看所有存档状态信息"
    # 关闭后台自查功能
    elif [ "${OPTION}" == "disable" ];then
      # 只有开启了才能正确关闭
      if [[ $(_checkPid "${ROBOT_SCREEN_NAME}") != ""  ]]; then
        # 直接杀死进程
        ps -ef| grep "${ROBOT_SCREEN_NAME}"|grep -v grep |awk '{print $2}'|xargs kill -9
        screen -wipe >> /dev/null

        echo "存档 ${CLUSTER_NAME} 聊天互动功能已关闭"
        _printLog "存档 ${CLUSTER_NAME} 聊天互动功能已关闭" "${ROBOT_LOG_FILE}"

        echo ""
        echo "使用命令: bash $0 status 可查看所有存档状态信息"
      else
        echo "存档 ${CLUSTER_NAME} 尚未启动自查功能。"
        _printLog "存档 ${CLUSTER_NAME} 尚未启动自查功能。" "${ROBOT_LOG_FILE}"

        echo ""
        echo "使用命令: bash $0 status 可查看所有存档状态信息"
      fi
    # 其他
    else
      _robotUsageTip
    fi
  else
    echo "存档 ${CLUSTER_NAME} 尚未运行，请确保游戏已启动，再尝试自查功能。"
    _printLog "存档 ${CLUSTER_NAME} 尚未运行，请确保游戏已启动，再尝试自查功能。" "${ROBOT_LOG_FILE}"
  fi
}

# 脚本目录判断
result=$(ls "${SCRIPT_DIR}"|grep -c "dontstarve_dedicated_server")
if [ "${result}" == 0 ]; then
  echo "ERROR:脚本目录不正确!"
  echo "  尝试 方式一: 本脚本必须在指定目录下（默认方式）"
  echo "             将脚本 $0 放置在饥荒目录的 bin 或者 bin64 目录下，确保与启动文件 dontstarve_dedicated_server_nullrenderer 同级"
  echo ""
  echo "      方式二: 本脚本可放置任何目录下"
  echo "             将本脚本配置区变量 'SCRIPT_DIR=\"$(cd ~/dstserver/bin64/ && pwd)\"' 修改为饥荒启动文件正确路径并去掉前面的注释字符 '#'"
  exit 1
fi

# 参数-h或者--help给出完整语法提示
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  _usageTip
fi

# 没有位置参数给出简短语法提示
if [[ $# == 0 ]];then
  _simpleUsageTip
  exit 1
fi

# 存档目录不存在提示
if [[ update != ${COMMAND} ]] && [[ -n ${CLUSTER_NAME} ]] && [[ ! -d "${CLUSTER_PATH}/${CLUSTER_NAME}" ]];then
  echo "ERROR: ${CLUSTER_NAME} 存档目录不存在！"
  _simpleUsageTip
  exit 1
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
	    func_status
	  else
	    func_status "${CLUSTER_NAME}"
	  fi
		;;
  'send')
  	# send 命令必须携带消息，否则给出提示
	  if [[ -z "${CLUSTER_NAME}" ]] || [[ -z "${OPTION}" ]]; then
	    _sendUsageTip
	  fi
  	func_sendMsg "${CLUSTER_NAME}" "${OPTION}"
  	;;
   'ban')
   	# ban 命令必须携带禁止玩家的ID
 	  if [[ -z "${CLUSTER_NAME}" ]] || [[ -z "${OPTION}" ]]; then
 	    _banUsageTip
 	  fi
   	func_ban "${CLUSTER_NAME}"
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
  'update')
	  # 没有位置参数意味着手动更新
	  if [[ -z "${CLUSTER_NAME}" ]];then
	    func_update
	    exit 0
	  fi

	  # 存在位置参数为自动更新的开关设置
	  func_update "${CLUSTER_NAME}"
  	;;
  'robot')
	  # robot 后面参数错误提示
	  if [[ -z "${CLUSTER_NAME}" ]];then
	    _robotUsageTip
	  fi

	  # 无参数则直接启动，有参数则后台启动
	  if [ -z "${OPTION}" ];then
  	  func_robot "${CLUSTER_NAME}"
  	else
  	  func_robotSwitch "${CLUSTER_NAME}" "${OPTION}"
	  fi

  	;;
	*)
		_simpleUsageTip
		exit 1
esac
exit 0




