#!/bin/bash

HOME_PATH="/home/steam/dstserver/"
LOG_FILE="${HOME_PATH}/bin64/update.log"
TMP_FILE="${HOME_PATH}/bin64/tmp.msg"
APP_NAMEARR=("Cluster_3" "Cluster_2")

lastTime_version=`cat ${HOME_PATH}/version.txt`
~/Steam/steamcmd.sh +force_install_dir ~/dstserver/ +login anonymous +app_update 343050 +quit > ${TMP_FILE}
current_version=`cat ${HOME_PATH}/version.txt`

if [[ ${lastTime_version} != ${current_version}  ]];then
  for APP_NAME in ${APP_NAMEARR[@]};do
    bash ${HOME_PATH}/bin64/dst.sh restart ${APP_NAME}
    echo "[ `date '+%Y-%m-%d %H:%M:%S'` ] 检测到版本更新，存档 ${APP_NAME} 已重启，旧版本号：${lastTime_version}  新版本号：`cat ${HOME_PATH}/version.txt`" >> ${LOG_FILE}
  done
fi
