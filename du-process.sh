#!/bin/sh
#
# @file process.sh
# @brief 
# @author zhoujinze, zhoujz@chinanetcenter.com
# @version 0.0.2
# @date 2014-06-18
#

#script debug on
sh_dbg=1
dbg_echo(){
  if [ ! -z $sh_dbg  ]; then
    echo "$1"
  fi
}

#script default setting
default_plot_term=wxt
plot_term=$default_plot_term
olog_append_name=uuu

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
dm_cnnt=\$2
dm_flag=" "

usage(){
  echo "----------"
}

while getopts :ho:b:l:t:f: OPTION
do
  case $OPTION in
  f)init_log_file=$OPTARG
    echo "input logfile is $log_file"
    ;;
  o)plot_term=$OPTARG
    echo "plot output mode set to $plot_out_mode"
    ;;
  t)format_file=$OPTARG
    ;;
  b)base_line=$OPTARG
    ;;
  l)rec_len=$OPTARG
    ;;
  \?) #usage
    usage
    ;;
  esac
done

log_file=$init_log_file.tmp
plot_file=.$log_file.plot
plot_tmp_file=.$log_file.tmpplot
gnuplot_script=.$log_file.gnuplot

if [  -z $format_file ];then
  echo "Use default format!"
else
  #read log format info
  cat $format_file | while read line
  do
    if expr "$line" : '^#'>/dev/null;then
      continue
    fi
    eval $(echo $line)
    echo $line
  done
fi

#获得绘图区间 
#最大时间
#$1-filename,$2-domain, $3-var_name
get_file_max_t() {
  dbg_echo  "$2 $3"
  eval $(awk -F "$dm_flag" 'BEGIN {max=0} {if (max < '$2') max = '$2'} END {print "'$3'="max}' $1)
  echo "file:$1, domain:$2, varname:$3"
}


#$1-filename,$2-domain, $3-var_name $4-max
get_file_min_t() {
  eval $(awk -F "$dm_flag" 'BEGIN {min="'$4'"} {if (min > '$2') min = '$2'} END {print "'$3'="min}' $1)

  echo "file:$1, domin:$2, max:$4"
}

#如果取部分点绘图
if [ -z $base_line ]; then 
  cp -rf $init_log_file $log_file
  base_line=1
  eval $(awk '{print "rec_len="NR}' $init_log_file)
  echo "rec_len:$rec_len"
else
  if [ -z $rec_len ]; then 
    rec_len=1000
  fi
  fin_line=$(($base_line+$rec_len))
  echo "baseline:$base_line  finish line:$fin_line"
  awk 'NR>='$base_line'&&NR<'$fin_line'{print $0}' $init_log_file> $log_file
fi

#获取时间最大最小
get_file_max_t "$log_file" $dm_stime "max_t"
echo "=====================max_t:$max_t==========================="

get_file_min_t "$log_file" $dm_stime "min_t" $max_t 
echo "=====================min_t:$min_t==========================="

#获取连接最大最小
get_file_max_t "$log_file" $dm_cnnt "max_cnnt"
echo "=====================max_cnnt:$max_cnnt==========================="

get_file_min_t "$log_file" $dm_cnnt "min_cnnt" $max_cnnt
echo "=====================min_cnnt:$min_cnnt==========================="


#绘图参数
#全局  x-y  x-y1
space_1=26
space_2=15
space_3=10
space_4=10

#绘图数据
awk -F "$dm_flag" '{printf "%-'$space_1's %-'$space_2's %-'$space_3's %-'$space_4's\n", ('$dm_stime'-'$min_t'), '$dm_cnnt'/10000, $5, ($5+$6+$7+$8+$9+$10+$11+$12)/8}' $log_file> $plot_file

#$1-title 2-max_t 3-min_t 4-max_sp 5-min_sp 6-max-y2, 7-min-y2
set_plot_env(){
  time_len=$(($2-$3))
  plot_xlen=$(($time_len+1))

  #20个间隔
  plot_xnum=20
  plot_xtics=$(($plot_xlen+$plot_xnum))
  plot_xtics=$(($plot_xtics/$plot_xnum))

  plot_xrange_r=$(($plot_xlen+$plot_xnum))

  echo "max_t:$2, min_t:$3 plot_xlen:$plot_xlen plot_xtics:$plot_xtics"

  #使用浮点数运算
  eval $(echo "$4, $5" | awk '{print "plot_ylen="$1-$2}')
  eval $(echo "$6, $7" | awk '{print "plot_y2len="$1-$2}')

  #20个间隔
  plot_ynum=20
  eval $(echo "$plot_ylen, $plot_ynum" | awk '{print "plot_ytics="$1/$2}')
  echo "plot_ylen:$4 - $5 = $plot_ylen, ynum:$plot_ynum, ytics:$plot_ytics"
  
  eval $(echo "$plot_y2len, $plot_ynum" | awk '{print "plot_y2tics="$1/$2}') 
  echo "plot_y2len:$6 - $7 = $plot_y2len, ynum:$plot_ynum, y2tics:$plot_y2tics"

  plot_yrange_l=$5
  plot_yrange_r=$4
  
  plot_y2range_l=$7
  plot_y2range_r=$6

  #根据log文件名生成图片title
  plot_title=`basename $1`
  echo "title:$plot_title"

cat > $gnuplot_script << end_of_message
#set terminal $plot_term size 1300,600
set terminal pngcairo font "monospace" size 1300,600

set title "$plot_title:BasePoint:$base_line-RecLen:$rec_len"
set xrange [0 : $plot_xrange_r]

set xtics 0,$plot_xtics,$plot_xrange_r
set ytics $plot_yrange_l,$plot_ytics,$plot_yrange_r
set ytics nomirror
set y2tics $plot_y2range_l,$plot_y2tics,$plot_y2range_r
set grid
plot "$plot_file" u 1:2 w lp pt 5 lc 3 axis x1y1 t "cnnt", "$plot_file" u 1:3 w lp pt 7 lc 4 axis x1y2 t "cpu", "$plot_file" u 1:4 w lp pt 7 lc 6 axis x1y2 t "cpu-avr"
end_of_message
}

eval $(echo "$max_cnnt, 10000" | awk '{print "max_cnnt="$1/$2}')
eval $(echo "$min_cnnt, 10000" | awk '{print "min_cnnt="$1/$2}')

set_plot_env "CNNT-CPU-PIC" $max_t $min_t $max_cnnt $min_cnnt 100 0

gnuplot -p $gnuplot_script > $log_file-base-$base_line-len-$rec_len.png

exit 0

