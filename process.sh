#
# @file process.sh
# @brief 
# @author zhoujinze, zhoujz@chinanetcenter.com
# @version 0.0.2
# @date 2014-06-18
#
#!/usr/bin/env bash

#script debug on
sh_dbg=1

#script run time
dt=`date +%F-%T`
curdir=`pwd`

#script default setting
default_plot_term=wxt
plot_term=$default_plot_term
olog_append_name=uuu

#多log文件，为在同一图形上展示
#默认将时间归一
same_start_time=1

########################################
#文件格式匹配区 不同格式log文件通过-t选项指定格式说明文件
#进行匹配
#'$dm_mode' mode
#'$dm_size' size
#'$dm_time' time
dm_mode=\$6
dm_size=\$20
dm_time=\$24
dm_stime=\$1
dm_flag=" "

test_mode="mscc_r_NSS_Init_N_6 mscc_r_NSS_Init_N_2 mscc_r_Init_N_2 mscc_r_Init_N_6 bic"

dbg_echo(){
  if [ ! -z $sh_dbg  ]; then
    echo "$1"
  fi
}

process_usage() {
  echo "usage:$0 [-f log-file, must set] [-n remote-file-size, must set] [-o gnuplot term mode, default $default_plot_term] [-m mode] [-s no same time level]"
  exit 1
}


while getopts :ht:m:n:f:o:s OPTION
do
  case $OPTION in
  f)log_file=$OPTARG
    echo "input logfile is $log_file"
    ;;
  o)plot_term=$OPTARG
    echo "plot output mode set to $plot_out_mode"
    ;;
  n)#fsize=$OPTARG
    echo "reomte file size set to $fsize"
    eval $(echo "fsize=($OPTARG)" | sed -e 's/,/ /g')
    echo "reomte file first size set to ${fsize[*]}"
    ;;
  s)same_start_time=0
    echo "MultiFile do not set same start time"
    ;;
  t)format_file=$OPTARG
    ;;
  m)test_mode=$OPTARG
    ;;
  h)#usage
    process_usage
    ;;
  \?) #usage
    process_usage
    ;;
  esac
done

#参数检查
#if [ [ -z $log_file ] -a [ -z $fsize ] ]; then
echo "logfile:$log_file,  remote file size:$fsize"
if [ -z $log_file ]; then
  echo "INPUT LOG FILE or REMOVE FILE SIZE do not set"
  process_usage
fi

if [ -z $fsize ]; then
  echo "INPUT LOG FILE or REMOVE FILE SIZE do not set"
  process_usage
fi

#使用配置文件定义覆盖当前文件
if [  -z $format_file ];then
  echo "Use default format!"
else
  #read log format info
  while read line
  do
    if expr "$line" : '^#'>/dev/null;then
      continue
    fi
    eval $(echo $line)
    echo $line
  done<$format_file 
fi
echo $dm_mode
echo $dm_size
echo $dm_time
echo $dm_stime
echo $dm_flag

#目录文件归一化
#对目录进行聚合绘图与单独绘图输出
#聚合绘图包含两种模式,默认时间归一.可选时间分离
if [ -d $log_file ]; then
  echo "Dir name:$log_file"
  #文件列表
  eval $(echo "log_dir=$log_file" | sed -e 's/\/$//g')
  log_dir=$log_dir\/
  echo $log_dir
  log_file_list=`ls $log_file`
  echo "dir:$log_dir, file list:$log_file_list"
else
  echo "file name:$log_file"
  eval $(echo "log_file_list=\"$log_file\"" | sed -e 's/,/ /g')
fi

eval $(echo $log_file_list | awk '{print "file_num="NF}')
echo "file num=$file_num"
mrd_file=$log_file.mkd

#文件名格式预处理,文件名中_替换为:,或与window兼容反之
for file in $log_file_list
do
  eval $(echo "tfile=$file"| sed -e 's/_/:/g')
  tmplist="$tmplist $tfile"
  mv $file $tfile
  echo "Filelist:$tmplist"
done
log_file_list=$tmplist

########################
process_exit() {
  exit_code=$1
  #rm -rf $gnuplot_script
  for mode in $test_mode
  do
    echo "remove file: $dt-$mode-ts-$olog_append_name.log"
    rm -rf $dt-$mode-ts-$olog_append_name.log
    rm -rf $plot_data_file
  done

  if [ $exit_code -eq 0 ]; then
    echo "----------------process finish------------------"
  else
    echo "!!!!!!!!!!!!!process err,chk log!!!!!!!!!!!!!!!!"
  fi

  exit $exit_code
}

#获得绘图区间 
#最大时间
#$1-filename,$2-file_no
get_file_max_t() {
  max_file_t[$2]=0
  for mode in $test_mode
  do
    eval $(awk -F "$dm_flag" 'BEGIN {max=0} {if ('$dm_mode'=="'$mode'" && max < $1) max = $1} END {print "mode_max="max}' $1)
    dbg_echo "mode get max time:$mode $mode_max"
    if [ ${max_file_t[$2]} -lt $mode_max ]; then
      max_file_t[$2]=$mode_max
    fi
  done
  echo "file:$1, max_time:${max_file_t[$2]}"
}

#获取所有文件中的最长时间
max_t=0
file_no=0
for file in $log_file_list
do
  get_file_max_t "$log_dir$file" $file_no
  dbg_echo "file get max time:$log_dir$file ${max_file_t[$file_no]}"
  if [ $max_t -lt ${max_file_t[$file_no]} ]; then
    max_t=${max_file_t[$file_no]}
  fi
  file_no=$(($file_no+1))
done
echo "=====================max_t:$max_t==========================="

#$1-filename,$2-file_no
get_file_min_t() {
  #time_domain="\$1"
  min_file_t[$2]=$max_t
  for mode in $test_mode
  do
    eval $(awk -F "$dm_flag" 'BEGIN {min="'$max_t'"} {if ('$dm_mode'=="'$mode'" && min > $1) min = $1} END {print "mode_min="min}' $1)
    dbg_echo "mode get min time:$mode $mode_min"
    if [ ${min_file_t[$2]} -gt $mode_min ]; then
      min_file_t[$2]=$mode_min
    fi
  done
  echo "file:$1, min_time:${min_file_t[$2]}"
}

#获取所有文件中的最小时间
min_t=$max_t
file_no=0
for file in $log_file_list
do
  get_file_min_t "$log_dir$file" $file_no
  dbg_echo "file get min time:$log_dir$file ${min_file_t[$file_no]}"
  if [ $min_t -gt ${min_file_t[$file_no]} ]; then
    min_t=${min_file_t[$file_no]}
  fi
  file_no=$(($file_no+1))
done
echo "=====================min_t:$min_t==========================="

#$1-filename,$2-file_no
get_file_max_speed() {
  #time_domain="\$1"
  max_file_sp[$2]=0
  for mode in $test_mode
  do
    eval $(awk -F "$dm_flag" 'BEGIN {max=0} {if ('$dm_mode'=="'$mode'" && max < '$dm_size'/'$dm_time') max = '$dm_size'/'$dm_time'} END {print "mode_max="max}' $1)
    dbg_echo "mode:$mode mode_max_speed:$mode_max"
    if [ $(echo "${max_file_sp[$2]} < $mode_max"| bc) -eq 1 ]; then
      max_file_sp[$2]=$mode_max
    fi
  done
  echo "file:$1, max_sp:${max_file_sp[$2]}"
}

#获取所有文件中的最大速度
max_sp=0
file_no=0
for file in $log_file_list
do
  get_file_max_speed "$log_dir$file" $file_no
  dbg_echo "file get max speed:$log_dir$file ${max_file_sp[$file_no]}"
  if [ $(echo "$max_sp < ${max_file_sp[$file_no]}" | bc) -eq 1 ]; then
    max_sp=${max_file_sp[$file_no]}
  fi
  file_no=$(($file_no+1))
done
echo "=====================max_sp:$max_sp==========================="

#$1-filename,$2-file_no
get_file_min_speed() {
  #time_domain="\$1"
  min_file_sp[$2]=$max_sp
  for mode in $test_mode
  do
    eval $(awk -F "$dm_flag" 'BEGIN {min="'$max_sp'"} {if ('$dm_mode'=="'$mode'" && min > '$dm_size'/'$dm_time') min = '$dm_size'/'$dm_time'} END {print "mode_min="min}' $1)
    dbg_echo "mode:$mode mode_min_speed:$mode_min"
    if [ $(echo "${min_file_sp[$2]} > $mode_min"| bc) -eq 1 ]; then
      min_file_sp[$2]=$mode_min
    fi
  done
  echo "file:$1, min_sp:${min_file_sp[$2]}"
}

min_sp=$max_sp
file_no=0
for file in $log_file_list
do
  get_file_min_speed "$log_dir$file" $file_no
  dbg_echo "file get min speed:$log_dir$file ${min_file_sp[$file_no]}"
  if [ $(echo "$min_sp > ${min_file_sp[$file_no]}" | bc) -eq 1 ]; then
    min_sp=${min_file_sp[$file_no]}
  fi
  file_no=$(($file_no+1))
done
echo "=====================min_speed:$min_sp========================="

#多文件间使用相对时间
#min_t=0 max_t取最大间隔
if [ $same_start_time -eq 1 ]; then 
  min_t=0
  max_t=0
  file_no=0
  for file in $log_file_list
  do
    dbg_echo "maxt:${max_file_t[$file_no]}, mint:${min_file_t[$file_no]},file_no:$file"
    max_file_tmp=$((${max_file_t[$file_no]} -  ${min_file_t[$file_no]}))
    dbg_echo "time-len:$max_file_tmp"
    if [ $max_t -lt $max_file_tmp ]; then
      max_t=$max_file_tmp
    fi
    file_no=$(($file_no+1))
  done
fi
echo "=====================maxt:$max_t, min_t:$min_t========================="

#获得格式化曲线数据
#各列占用空间
space_1=26
space_2=10


#开始生成markdown文档
cat >$mrd_file<<end_of_mrd
# 数据文件信息
(待实现)
end_of_mrd

#$1-filename, $2-fileno
get_file_plot_data() {
  for mode in $test_mode
  do
    eval $(echo $1|sed -e 's/.*\///g' -e 's/\(....-.*-.*-.*:.*:..\)\(.*$\)/lc_plot_file=.\1_"'$mode'"-"'$olog_append_name'".data/g')
    plot_data_file="$plot_data_file $lc_plot_file"
    dbg_echo "lc_plot_file:$lc_plot_file, plot_data_file:$plot_data_file"

    comment_note="#$mode-time"
    mode_strlen=`expr length "$comment_note"`
    space_num=$(($space_1-$mode_strlen))
    dbg_echo "space_num:$space_num, cmdnote:$comment_note, modlen:$mode_strlen"
    while [ $space_num -gt 0 ]
    do
      comment_note=$comment_note" "
      space_num=`expr $space_num - 1`
    done
    comment_note=$comment_note" Speed"
    echo "$comment_note" > $lc_plot_file

    for index in $(seq 0 $((${#fsize[@]} - 1)))
    do
      #获取时间和速度信息
      dbg_echo "File:$1, index:$index, size:${fsize[$index]}"

      if [ $same_start_time -eq 1 ]; then 
        awk -F "$dm_flag" '{if('$dm_mode'=="'$mode'" && '$dm_size' == '${fsize[$index]}')printf "%-'$space_1's %-'$space_2's\n", ('$dm_stime'-'${min_file_t[$2]}')/1000, '$dm_size'/'$dm_time'}' $1>> $lc_plot_file
      else
        awk -F "$dm_flag" '{if('$dm_mode'=="'$mode'" && '$dm_size' == '${fsize[$index]}')printf "%-'$space_1's %-'$space_2's\n", ('$dm_stime'-'$min_t')/1000, '$dm_size'/'$dm_time'}' $1>> $lc_plot_file
      fi
      #awk -F "$dm_flag" 'BEGIN {print "'"$comment_note"'"}{if('$dm_mode'=="'$mode'" && '$dm_size' == '${fsize[$index]}')printf "%-'$space_1's %-'$space_2's\n", ($1-'${min_file_t[$2]}')/1000, '$dm_size'/'$dm_time'}' $1>> $lc_plot_file
    done
    #按时间排序
    sort -n -k 1 $lc_plot_file -o $lc_plot_file 
  done
}

#生成图形数据文件
file_no=0
for file in $log_file_list
do
  get_file_plot_data "$log_dir$file" $file_no
  file_no=$(($file_no+1))
done
echo "=============================finish gen plot_data_file=========================="

#设置全局绘图参数
gnuplot_script=.gnuplot_script.plot

#$1-title 2-max_t 3-min_t 4-max_sp 5-min_sp
set_plot_env(){
  time_len=$(($2-$3))
  plot_xlen=$(($time_len+1000))
  plot_xlen=$(($plot_xlen/1000))

  #20个间隔
  plot_xnum=20
  plot_xtics=$(($plot_xlen+$plot_xnum))
  plot_xtics=$(($plot_xtics/$plot_xnum))
  plot_xrange_r=$(($plot_xlen+$plot_xnum))

  echo "max_t:$2, min_t:$3 plot_xlen:$plot_xlen plot_xtics:$plot_xtics"

  #速率使用浮点数运算
  eval $(echo "$4, $5" | awk '{print "plot_ylen="$1-$2}')
  #20个间隔
  plot_ynum=20
  #define plot_ytics=$(($plot_ylen/$plot_ynum))
  eval $(echo "$plot_ylen, $plot_ynum" | awk '{print "plot_ytics="$1/$2}')
  echo "plot_ylen:$4 - $5 = $plot_ylen, ynum:$plot_ynum, ytics:$plot_ytics"

  plot_yrange_l=$5
  plot_yrange_r=$4

  #根据log文件名生成图片title
  plot_title=`basename $1`
  echo "title:$plot_title"

cat > $gnuplot_script << end_of_message
#set terminal $plot_term size 1300,600
set terminal pngcairo font "monospace" size 1300,600

set title "speed-time:$plot_title"
set xrange [0 : $plot_xrange_r]

set xtics 0,$plot_xtics,$plot_xrange_r
set ytics $plot_yrange_l,$plot_ytics,$plot_yrange_r
end_of_message

}

#绘制各曲线
#绘制多文件聚合图
get_plot_cmd(){
  plot_cmd="plot "
  #rgb color
  plot_color[0]=32
  plot_color[1]=32
  plot_color[2]=32
  i=0
  dbg_echo "plot_data_file:$1"
  #制表
  echo "mode|Average Speed(KB/s)|Points  " >> $mrd_file
  echo "---|---|--- " >> $mrd_file
  for gpfile in $1
  do
    eval $(wc -l $gpfile | awk '{print "_fz="$1}')
    echo "output file line number: $_fz,file:$gpfile"

    if [ $_fz -le 1 ]; then
      continue
    fi
  
    if expr "$gpfile" : '.swp$'>/dev/null; then
      continue
    fi

    #对输入文件名的格式有日期格式要求
    eval $(echo "$gpfile" | sed -e 's/.\(....-..-..-..:..:..\)\(.*\)-'"$olog_append_name"'.data$/mode=\1\2/g')

    #average speed
    eval $(awk '{if($1~/^[0-9]/) sum+=$2; num+=1} END {print "avr_speed="sum/num}' $gpfile)

    #color
    red=`echo "obase=16;${plot_color[2]}" | bc`
    green=`echo "obase=16;${plot_color[1]}" | bc`
    blue=`echo "obase=16;${plot_color[0]}" | bc`

    index=$(($i%3))
    j=$(($i/3))
	  i=$(($i+1))


    dbg_echo "mode:$mode avrspeed:$avr_speed, index:$index"
    plot_color[$index]=$(($j*74+96))
    if  [ ${plot_color[$index]} -gt 255 ]; then
      plot_color[$index]=255
    fi

    rgb_color=\#$red$green$blue
    echo "rgb_color:$rgb_color"

    echo "$mode|$avr_speed|$_fz  " >> $mrd_file

    #echo "$mode $avr_speed $_fz" | awk '{printf "mode:%-50s avr_sp:%-10sKB/s point:%-5s  \n", $1, $2, $3}' >> tmp
    #plot_cmd=$plot_cmd"\"$gpfile\" w lp lc rgbcolor \"$rgb_color\" pt 7 title \"$mode:$avr_speed\","
    plot_cmd=$plot_cmd"\"$gpfile\" w lp lc $i pt 7 title \"$mode:$avr_speed\","
    #plot_cmd=$plot_cmd"\"$gpfile\" w lp lc $i  pt 1 title \"$mode:$avr_speed\","
  done
  #添加空行
  echo "">>$mrd_file
  #无匹配点退出
  if [ $i -eq 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!Not record match, Please Check Input Param:1!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "param:$1!!!!!!!!!!!!!!!!!!!!!!!!!"
    process_exit 1
  fi
  #dbg_echo "plot_cmd:$plot_cmd"
}

#绘制聚合图形文件，log_dir为空时不需要绘制
if [ $file_num -le 1 ];then
  echo "Single File log, do not need to Gen AG Pic"
else
  #$1-title 2-max_t 3-min_t 4-max_sp 5-min_sp
  echo "# 聚合曲线图" >> $mrd_file
  set_plot_env "AG-Pic" $max_t $min_t $max_sp $min_sp
  get_plot_cmd "$plot_data_file"
  echo $plot_cmd | sed 's/,$//g'>>$gnuplot_script
  gnuplot -p $gnuplot_script > $log_file.png

  #add to doc
  echo "![]($curdir/$log_file.png)">>$mrd_file
  echo "# 统计直方图" >> $mrd_file
  echo "(待实现)" >> $mrd_file
fi

echo "=====================Finish AG Picture Generation==================="
#log文件独立图形
file_no=0
#add to doc
echo "# LOG文件独立绘图 ">> $mrd_file

for file in $log_file_list
do
  #add to doc
  echo "## $file" >> $mrd_file
  echo "### 曲线图" >> $mrd_file

  #Get file log time
  eval $(echo "$file" | sed -e 's/\(....-..-..-..:..:..\).*/file_log_time=\1/g')
  dbg_echo "=========search file:$file_log_time========"

  #相关中间文件
  plot_sg_file=`ls .$file_log_time*`
  dbg_echo "time:$file_log_time; $plot_sg_file"
  
  #设定绘图环境
  eval $(echo "sg_file=$file" |sed -e 's/[-:\.]/_/g')
  echo "sg-----file:$sg_file"

  #$1-title 2-max_t 3-min_t 4-max_sp 5-min_sp
  #set_plot_env $sg_file ${max_file_t[$file_no]} ${min_file_t[$file_no]} ${max_file_sp[$file_no]} ${min_file_sp[$file_no]}
  set_plot_env $log_file ${max_file_t[$file_no]} ${min_file_t[$file_no]} ${max_file_sp[$file_no]} ${min_file_sp[$file_no]}
  #set_plot_env "$file" 200 100 100 200
  #set_plot_env $log_file $max_t $min_t $max_sp $min_sp
  #得到绘图命令
  get_plot_cmd "$plot_sg_file"
  dbg_echo "$plot_cmd"
  #绘图命令入绘图脚本
  echo $plot_cmd | sed 's/,$//g'>>$gnuplot_script
  gnuplot -p $gnuplot_script > $file.png

  echo "![]($curdir/$file.png)" >> $mrd_file
  
  echo "### 统计直方图" >> $mrd_file
  echo "(待实现)" >> $mrd_file
  #直方图
  file_no=$(($file_no+1))
done
process_exit 0
exit 0

#log文件独立直方图
for mode in $test_mode
do
  eval $(wc -l $dt-$mode-ts-$olog_append_name.log | awk '{print "_fz="$1}')
  echo "output file line number: $_fz"
  if [ $_fz -le 1 ]; then
    continue;
  fi
  eval $(awk '{if($1~/^[0-9]/) sum+=$2; num+=1} END {print "avr_speed="sum/num}' $dt-$mode-ts-$olog_append_name.log)
  echo "mode:$mode avrspeed:$avr_speed"

  #生成命令追加
  plot_cmd=$plot_cmd"\"$dt-$mode-ts-$olog_append_name.log\" w lp lc $i pt 7 title \"$mode:$avr_speed\","
	i=$(($i+1))
done

echo $plot_cmd | sed 's/,$//g'>>$gnuplot_script

#执行gnuplot脚本
gnuplot -p $gnuplot_script > $log_file.png

#整合输出汇总数据
summary_out=`basename $log_file`-summary

for mode in $@
do
  cmd_gen_file=$cmd_gen_file" $dt-$mode-ts-$olog_append_name.log"
done

awk 'BEGIN { 
  findex[ARGC];
  for(t=1;t<=ARGC;t++) { 
    findex[t]=0; 
  } 
}

{ 
  { 
    for(t=1;t<=ARGC;t++) {
      if(FILENAME==ARGV[t]) { 
        line[t,findex[t]]=$0;
        findex[t]++; 
      }
    }
  } 
}
END { 
  maxcount=0; 
  nstr=sprintf("%-'$space_1's %-'$space_2's", " ", " ");
 
  for(i=1;i<=ARGC;i++) { 
    if(findex[i]>maxcount) maxcount=findex[i]; 
  } 
  for(j=0;j<maxcount;j++) { 
    for(i=1;i<=ARGC;i++) { 
      #多个文件的当前行拼接成一行
      if(i==1) {
        if(length(line[i,j])==0) {
          #空行格式
          str=sprintf("%s", nstr);
        } else {
          str=line[i,j];
        }
      } else {
        #中间行为空，将行内容替换为固定空串
        if(length(line[i,j])==0) {
          str=sprintf("%s\t%s",str, nstr); 
        } else {
          str=sprintf("%s\t%s",str,line[i,j]); 
        }
      }
    }
    printf("%s\n",str); 
  }
}' $cmd_gen_file > $summary_out

#清理过程文件

#process_exit 0

