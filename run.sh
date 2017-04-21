#!/bin/bash
#
# Perform the fio test
# Created by zifeng.w

CUR_DIR=$(cd "$(dirname "$0")"; pwd)
cd ${CUR_DIR}
rm -rf job_files result
mkdir -p job_files result

CONFIG_DIR=${CUR_DIR}/job_files
RESULT_DIR=${CUR_DIR}/result
FIO_DIR=${CUR_DIR}/fio

install_fio() {
  command -v fio >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "$(fio --version) has already been installed."
  else
    echo "********************Installing FIO***************************"
    cd ${FIO_DIR}
    make; make install
    echo "********************FIO Installed****************************"
    cd ..
  fi
}

gen_config_file() {
  mode=$(sed -n "${line}p" config.in | awk -F "|" '{print $1}' | tr -d ' ')
  blocksize=$(sed -n "${line}p" config.in | awk -F "|" '{print $2}' | tr -d ' ')
  iodepth=$(sed -n "${line}p" config.in | awk -F "|" '{print $3}' | tr -d ' ' )
  runtime=$(sed -n "${line}p" config.in | awk -F "|" '{print $4}' | tr -d ' ')
  numjobs=$(sed -n "${line}p" config.in | awk -F "|" '{print $5}' | tr -d ' ')
  check="${mode}"

  if [[ ${check} == "END" ]]; then
    echo "Job files are under ${CONFIG_DIR}"
    echo ""
  else
    count=$(expr $line_t - 1)
    config_file="$count-$mode-$blocksize-$iodepth-$runtime.log"
    sed -i "s/config_blocksize/${blocksize}/" ${CUR_DIR}/configuration.tmp \
      >${CONFIG_DIR}/${config_file}
    sed -i "s/config_mode/${mode}/" ${CONFIG_DIR}/${config_file}
    sed -i "s/run_time/${runtime}/" ${CONFIG_DIR}/${config_file}
    sed -i "s/config_iodepth/${iodepth}/" ${CONFIG_DIR}/${config_file}
    sed -i "s/num_jobs/${numjobs}/" ${CONFIG_DIR}/${config_file}
  fi
}

configure() {
  echo "**********************Generating config Files********************"
  check="START"
  line_t=2
  until [[ ${check} == "END" ]]; do
    line=${line_t}
    gen_config_file
    line_t=$(expr ${line_t} + 1)
  done
  cd ${CONFIG_DIR}
  config_files=$(ls)
  echo ${config_files}
  echo "*********************Config Files Generated**********************"
  rm -rf ${CUR_DIR}/configuration.tmp
}

set_disks() {
  echo "*****************************************************************"
  echo "The following disks exist in your system:"
  ls /dev | grep sd[a-z][a-z]*$
  read -p "Which disk do you want to use for testing:" disk
  sed "s/config_path/${disk}/" ${CUR_DIR}/configuration \
    >${CUR_DIR}/configuration.tmp
}

running() {
  echo "********************Running FIO**********************************"
  jobnum=1
  echo "rw,iodepth,size,iops,bw,Lat,CPUusr,CPUsys" >>${RESULT_DIR}/result.csv
  for configuration in ${config_files}; do
    echo $(date +%m-%d" "%H:%M:%S) | tee "${jobnum}.txt"
    echo "Job ${jobnum} is Running.."
    fio "${configuration}" | tee -a "${jobnum}.txt"

    #output
    iops=$(less "${jobnum}.txt" | grep -w iops | awk -F "iops=" '{print $2}' \
      | awk -F "," '{print $1}')
    bw=$(less "${jobnum}.txt" | grep -w bw | awk -F "bw=" '{print $2}' \
      | awk -F "," '{print $1}')
    Lat=$(less "${jobnum}.txt" | grep -w lat | head -n 3 | tail -n 1 \
      | awk -F "avg=" '{print $2}' | awk -F "," '{print $1}')
    CPUusr=$(less "${jobnum}.txt" | grep -w cpu | awk -F "usr=" '{print $2}' \
      | awk -F "%" '{print $1}')
    CPUsys=$(less "${jobnum}.txt" | grep -w cpu | awk -F "sys=" '{print $2}' \
      | awk -F "%" '{print $1}')
    iodepth=$(less "${configuration}" | grep -w iodepth | awk -F "=" '{print $2}')
    rw=$(less "${configuration}" | grep -w rw | awk -F "=" '{print $2}' | head -n 1)
    size=$(less "${configuration}" | grep -w bs | awk -F "=" '{print $2}' | head -n 1)
    runtime=$(less "${configuration}" | grep -w runtime | awk -F "=" '{print $2}')
    echo "iodepth=$iodepth, transfer request size=$size, 100% $rw, runtime=$runtime"
    echo "IOPS=$iops"
    echo "bw=$bw"
    echo "Lat(usec)=$Lat"
    echo "CPUusr=$CPUusr"
    echo "CPUsys=$CPUsys"

    echo "$rw,$iodepth,$size,$iops,$bw,$Lat,$CPUusr,$CPUsys" \
      >>${RESULT_DIR}/result.csv

    echo "iodepth=$iodepth, transfer request size=$size, 100% $rw, runtime=$runtime" \
      >> $RESULT_DIR/result.log
    echo "IOPS=$iops" >>$RESULT_DIR/result.log
    echo "bw=$bw" >>$RESULT_DIR/result.log
    echo "Lat(usec)=$Lat" >>$RESULT_DIR/result.log
    echo "CPUusr=$CPUusr" >>$RESULT_DIR/result.log
    echo "CPUsys=$CPUsys" >>$RESULT_DIR/result.log
    jobnum=$(expr $jobnum + 1)
    clear
  done
  echo "***********************Finished***************"
}

#main
clear
echo "Welcome to FIO test."
sleep 2
set_disks
clear
install_fio
clear
configure
clear
running
cat ${RESULT_DIR}/result.log
echo "Test finished."
echo "Test result is under ./result"

