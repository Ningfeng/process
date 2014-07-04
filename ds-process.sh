#!/usr/bin/env bash
#
# @file ds-process.sh
# @brief 
# @author zhoujinze, zhoujz@chinanetcenter.com
# @version 0.0.8
# @next version 0.0.9
#       Add MultiMode Log file support
# @date 2014-07-03
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

dsusage(){
  echo "-----------------------------"
  echo "usage:$0 [-f log-file, must set] [-t select cfg file]"
  echo "-----------------------------"
  exit $1
}

while getopts :ho:b:l:t:f: OPTION
do
  case $OPTION in
  f)init_log_file=$OPTARG
    echo "input logfile is $init_log_file"
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
  \?) #dsusage
    dsusage 1
    ;;
  esac
done

log_file=$init_log_file.tmp
plot_file=.$log_file.plot
plot_tmp_file=.$log_file.tmpplot
gnuplot_script=.$log_file.gnuplot


#================================================
#曲线绘制所需元素
#一个横轴，两个纵轴信息
#横轴名称-两个纵轴名称
#横轴数据源-纵轴数据源
#指定的坐标范围，或者自动生成的坐标范围

#
#
dm_flag=","

#数据源 x域不可空，y1和y2至少一个不为空
dm_x=1
dm_y1="(13+14+16+17+18),24,30"
dm_y2=3
#Y轴属性
y1_attr="cpu"
y2_attr="syn"

#y1各曲线点对应的x数据源,
#可以为空默认取dm_x第一个x源，
#或者为每个Y1数据源指定x源
dm_y1_x=""
dm_y2_x=""

#分别x-y1-y2表明数据使用绝对值或相对值
x_relative="1"
y1_relative="0"
y2_relative="0"

#指定范围，不指定时通过数据源自动生成
x_max=
y1_max=100
y2_max=

x_min=
y1_min=0
y2_min=

#scale值，数据源数据将除以sacle值作为曲线坐标
x_scale=1
y1_scale=1
y2_scale=1

#数据名
name_x[0]=""
#Y1轴第1条曲线的名称
name_y1[0]=""
#Y2轴第1条曲线的名称
name_y2[0]=""

#每个数据源的名称，
#如未指定，将从以下指定行获取
name_main_line=6
name_sub_line=7

#曲线标题
plot_name=""

#绘图点风格设置
pty1=5
pty2=5
#绘图点大小设置
ptsy1=1
ptsy2=1
#绘图线宽设置
lwy1=1
lwy2=1

if [  -z $format_file ];then
  echo "Use default format!"
else
  #read log format info
  while read line
  do
    if expr "$line" : '^#'>/dev/null;then
      continue
    fi
    eval $(echo "$line")
    echo "$line"
  done < $format_file
fi

########参数判断#########
if [ -z $init_log_file ]; then
  echo "Special the log file..."
  dsusage 1
fi 

if [ -r $init_log_file ]; then
  echo "In LogFile:$init_log_file"
else
  echo "LogFile:$init_log_file can't read"
  dsusage 1
fi

echo "===========test_param:$test_param============"

################################################
#多模文件，根据模式域，通过倍域方式转换为单模文件
#for going...or another script to do this job


################################################

#$1-var_name  $2-list
get_dm_list(){
  #逗号替换为空格-->数字前插入$--->去除数字间$--->去除]--->去除[$,还原立即数
  eval $(echo "$1=\"$2\""| sed  -e 's/,/ /g' -e 's/\([0-9]\)/\\$\1/g' -e 's/\([0-9]\)\\$\([0-9]\)/\1\2/g' -e 's/\]//g' -e 's/\[\\\$//g' -e 's/\([a-z]\)\\\$/\1/g')
  eval $(echo "dbg_echo \"$1:\$$1\"")
}

#$1-varname $2-dm
get_dm_num(){
  eval $(echo "$2" | awk -F "," '{print "'$1'="NF}')
  eval $(echo "dbg_echo \"get_dm_num,$1=\$$1\"")
}

#$1-filename,$2-domain, $3-var_name
get_dm_max_t() {
  local dm_tmp="$2"
  eval $(awk -F "$dm_flag" 'BEGIN {max=0} {if (max < '$dm_tmp') max = '$dm_tmp'} END {print "'$3'="max}' $1)

  eval $(echo "dbg_echo \"file:\$1, domain:\$2, $3:\$$3\"")
}

#$1-filename,$2-domain, $3-var_name $4-max
get_dm_min_t() {
  local dm_tmp="$2"

  eval $(awk -F "$dm_flag" 'BEGIN {min="'$4'"} {if (min > '$dm_tmp') min = '$dm_tmp'} END {print "'$3'="min}' $1)

  eval $(echo "echo \"file:\$1, domin:\$2, max:\$4 $3:\$$3\"")
}

#$1 filename, $2 dm-list, $3 var_name
get_mul_dm_max(){
  local dm_list=""
  local dm_tmp=""
  local max_tmp=""
  local max=0

  get_dm_list  "dm_list" "$2"

  for dm_tmp in $dm_list
  do
    get_dm_max_t "$1" "$dm_tmp" "max_tmp"
    if [ $(echo "$max_tmp > $max" | bc) -eq 1 ]; then
      max=$max_tmp
    fi
    dbg_echo "$dm_tmp-max_tmp:$max_tmp , max:$max"
  done
  eval $(echo "$3=\"$max\"")
  dbg_echo "$3 : $max"
}

#$1 filename, $2 dm-list, $3 var_name $4-max
get_mul_dm_min(){
  local dm_list=""
  local dm_tmp=""
  local min_tmp=""
  local min="$4"

  get_dm_list  "dm_list" "$2"

  for dm_tmp in $dm_list
  do
    get_dm_min_t "$1" "$dm_tmp" "min_tmp" "$4"
    if [ $(echo "$min_tmp < $min" | bc) -eq 1 ]; then
      min=$min_tmp
    fi
    dbg_echo "$dm_tmp-min_tmp:$min_tmp , min:$min"
  done
  eval $(echo "$3=\"$min\"")
  dbg_echo "$3 : $min"
}

#name   dm   line
get_dm_name(){
  local tmp=""
  local col="$2"
  local dm_tmp=\$$col

  if [ -z $col ]; then
    echo "Check the Param:-- $col --$3 --"
    return 0
  fi
  if [ -z "$3" ];then
    echo "Check the Param:-- $col --$3 --"
    return 0
  fi

  while [ -z "$tmp" ]
  do
    eval $(echo "$3" | awk -F "$dm_flag" '{print "tmp=\""'$dm_tmp',"\""}'| sed -e 's/ "/"/g' -e 's/ /_/g')
    col=$(($col-1))
    if [ $col -lt 1 ]; then
      break
    fi
    dm_tmp=\$$col
  done

  eval $(echo "$1=\"$tmp\"")
}

#name_list dm 
get_dm_name_list(){
  local dm_tmp="`echo $2 | sed -e 's/ //g'`"
  eval $(echo "$1=\"$dm_tmp\"" | sed -e 's/ //g' -e  's/\[.*\]//g' -e 's/[+-]/ /g' -e 's/[()\*\/]/ /g')

  eval $(echo "dbg_echo \"get_dn_name_list,$1:\$$1\"")
}

#多列
#name dm_list line
get_mdm_name(){
  local varname=$1
  local index=0
  local name_tmp=""
  local name_tmp2=""

  local dm_tmp=""
  local dm_tmp2=""

  local tmp_list=""
  local mlist="`echo $2 | sed -e 's/ //g' -e 's/,/ /g'`"

  echo "index:$index mlist:$mlist"

  for dm_tmp in $mlist
  do
    get_dm_name_list "tmp_list" "$dm_tmp"
    name_tmp=""
    for dm_tmp2 in $tmp_list
    do
      get_dm_name "name_tmp2" "$dm_tmp2" "$3"
      echo "----$name_tmp2"
      if [ -z $name_tmp ];then
        name_tmp=$name_tmp2
      elif [ $name_tmp != $name_tmp2 ]; then
        name_tmp=${name_tmp}_${name_tmp2}
      fi
    done

    eval $(echo "${varname}[$index]=$name_tmp")
    eval $(echo "dbg_echo \"${varname}[$index]:\${${varname}[$index]}\"")

    index=$(($index+1))
  done
}

#name  main_name sub_name
ms_org_name(){
  local tmp=""
  #如果main中包含sub
  echo "$2" | grep -q "$3"
  if [ $? -eq 0 ];then
    eval $(echo "tmp=\"$2\"")
  else
    #如果sub包含main
    echo "$3" | grep -q "$2"
    if [ $? -eq 0 ];then
      eval $(echo "tmp=\"$3\"")
    else
      eval $(echo "tmp=\"$2_$3\"")
    fi
  fi
  #去除空格,中间空格_替代
  eval $(echo "$1=\"$tmp\"" | sed -e 's/\(.*[0-9,a-z,A-Z]\) *\("\)$/\1\2/g' -e 's/ /_/g')
}


#根据设定获取图像描述信息
get_des_name(){
  local index=0
  local arr_size=0

  if [ $name_main_line == 0 -a $name_sub_line == 0 ]; then
    echo "name main/sub line is 0"
    #如果未设定名称
    if [ -z $name_x ];then
      name_x="X"
    fi

    #X轴
    index=0
    get_dm_num "arr_size" "$dm_x"
    while [ $index -lt $arr_size ]
    do
      if [ -z ${name_x1_sub[$index]}];then
        name_x1_sub[$index]="X$index"
      fi
      index=$(($index+1))
    done

    #Y1轴
    index=0
    get_dm_num "arr_size" "$dm_y1"
    while [ $index -lt $arr_size ]
    do
      if [ -z ${name_y1_sub[$index]}];then
        name_y1_sub[$index]="Y1$index"
      fi
      index=$(($index+1))
    done
    
    #Y2轴
    index=0
    get_dm_num "arr_size" "$dm_y2"
    while [ $index -lt $arr_size ]
    do
      if [ -z ${name_y2_sub[$index]}];then
        name_y2_sub[$index]="Y2$index"
      fi
      index=$(($index+1))
    done
    
  else
    local main_line=""
    local sub_line=""

    echo "name_main_line is $name_main_line, name_sub_line:$name_sub_line"
    if [ $name_main_line -gt 0 ]; then
      eval $(awk 'NR=='$name_main_line'{print "main_line="$0}' $init_log_file)
    fi
    if [ $name_sub_line -gt 0 ]; then
      eval $(awk 'NR=='$name_sub_line'{print "sub_line="$0}' $init_log_file)
    fi
    echo $main_line
    echo $sub_line

    echo "======================================================="
    if [ -n "$main_line" ]; then
      get_mdm_name "x_main" $dm_x "$main_line"
      echo "----get y1-main"
      get_mdm_name "y1_main" "$dm_y1" "$main_line"
      echo "----get y2-main"
      get_mdm_name "y2_main" "$dm_y2" "$main_line"
    fi
    echo "=====================main line end======================"
    if [ -n "$sub_line" ];then
      get_mdm_name "x_sub" "$dm_x" "$sub_line"
      get_mdm_name "y1_sub" "$dm_y1" "$sub_line"
      get_mdm_name "y2_sub" "$dm_y2" "$sub_line"
    fi
    echo "=====================sub line end======================="

    #X轴
    index=0
    get_dm_num "arr_size" "$dm_x"
    while [ $index -lt $arr_size ]
    do
      #如果配置文件中未设定，设置
      if [ -z ${name_x[$index]} ];then
        ms_org_name "name_x[$index]" "${x_main[$index]}" "${x_sub[$index]}"
      fi
      echo "name_x[$index]====${name_x[$index]}"
      index=$(($index+1))
    done
    #Y1轴
    index=0
    get_dm_num "arr_size" "$dm_y1"
    while [ $index -lt $arr_size ]
    do
      #如果配置文件中未设定，设置
      if [ -z ${name_y1[$index]} ];then
        ms_org_name "name_y1[$index]" "${y1_main[$index]}" "${y1_sub[$index]}"
      fi
      echo "name_y1[$index]====${name_y1[$index]}"
      index=$(($index+1))
    done

    #Y2轴
    index=0
    eval $(echo "$dm_y2" | awk -F "$dm_flag" '{print "arr_size="NF}')
    while [ $index -lt $arr_size ]
    do
      #如果配置文件中未设定，设置
      if [ -z ${name_y2[$index]} ];then
        ms_org_name "name_y2[$index]" "${y2_main[$index]}" "${y2_sub[$index]}"
      fi
      echo "name_y2[$index]====${name_y2[$index]}"
      index=$(($index+1))
    done

    plot_name=$name_x-$y1_attr-$y2_attr
  fi

  echo "===================des-end=============================="
  echo "X:$name_x"
  echo "pn:$plot_name"
}

get_des_name

######################################################

#设定log记录中起始记录行
if [  $name_sub_line -gt $name_main_line ]; then
  rec_start=$(($name_sub_line + 1))
else
  rec_start=$(($name_sub_line + 1))
fi

#抽取部分log信息
if [ -z $base_line ]; then 
  eval $(awk '{print "rec_len="NR}' $init_log_file)

  base_line=$rec_start
  rec_len=$(($rec_len-$rec_start))
  echo "rec_len:$rec_len"

  #去掉log头文件注释头部
  if [ $base_line -gt 1 ]; then
    fin_line=$(($base_line+$rec_len))
    #xxxx 可以添加注释行判定
    echo "==========================gen-tmp:$base_line->$fin_line====================================="
    awk 'NR>='$base_line'&&NR<'$fin_line'{print $0}' $init_log_file> $log_file
  else
    #log文件每一行均为有效记录
    echo "==========================gen-tmp:copy file====================================="
    cp -rf $init_log_file $log_file
  fi
else
  if [ $base_line -lt $rec_start ];then
    base_line=$rec_start
  fi

  if [ -z $rec_len ]; then 
    rec_len=1000
  fi
  fin_line=$(($base_line+$rec_len))
  echo "baseline:$base_line  finish line:$fin_line"
  #xxxx 可以添加注释行判定
  echo "==========================gen-tmp:$base_line->$fin_line====================================="
  awk 'NR>='$base_line'&&NR<'$fin_line'{print $0}' $init_log_file> $log_file
fi

####################################################################
#获得绘图区间 


#######################################
#获取坐标系最大最小值
#如配置文件设定，不需要遍历文件获取
#获取X轴最大最小

if [ -z $x_max ];then
  get_mul_dm_max "$log_file" "$dm_x" "x_max"
fi
echo "=====================x_max:$x_max==========================="

if [ -z $x_min ];then
  get_mul_dm_min "$log_file" "$dm_x" "x_min" "$x_max"
fi
echo "=====================x_min:$x_min==========================="

#获取Y1的最大最小
if [ -z $y1_max ];then
  get_mul_dm_max "$log_file" "$dm_y1" "y1_max"
fi
echo "=====================y1_max:$y1_max==========================="

if [ -z $y1_min ];then
  get_mul_dm_min "$log_file" "$dm_y1" "y1_min" $y1_max
fi
echo "=====================y1_min:$y1_min==========================="

#获取Y2的最大最小
if [ -z $y2_max ];then
  get_mul_dm_max "$log_file" "$dm_y2" "y2_max"
fi
echo "=====================y2_max:$y2_max==========================="

if [ -z $y2_min ];then
  get_mul_dm_min "$log_file" "$dm_y2" "y2_min" $y2_max
fi
echo "=====================y2_min:$y2_min==========================="


######################################################################
#绘图参数

############
#1.格式串
#2.数据串
data_str=""
dm_x_list=""
dm_y1_list=""
dm_y2_list=""

dm_x_nr=""
dm_y1_nr=""
dm_y2_nr=""

space_12=12

get_dm_num "dm_x_nr" "$dm_x"
get_dm_num "dm_y1_nr" "$dm_y1"
get_dm_num "dm_y2_nr" "$dm_y2"

get_dm_list "dm_x_list" "$dm_x"
get_dm_list "dm_y1_list" "$dm_y1"
get_dm_list "dm_y2_list" "$dm_y2"

dm_list="$dm_x_list $dm_y1_list $dm_y2_list"
index=0
for dm in $dm_list
do
  ds_aps=""
  if [ $index -lt $dm_x_nr ]; then
    scale=$x_scale
    if [ $x_relative -gt 0 ];then
      min=$x_min
      eval $(echo "$min $scale" | awk '{print "min="$1/$2}')
      ds_aps="($dm)/$scale-$min"
    else
      ds_aps="($dm)/$scale"
    fi
  elif [ $index -lt $(($dm_x_nr+$dm_y1_nr)) ];then
    scale=$y1_scale
    if [ $y1_relative -gt 0 ];then
      min=$y1_min
      eval $(echo "$min $scale" | awk '{print "min="$1/$2}')
      ds_aps="($dm)/$scale-$min"
    else
      ds_aps="($dm)/$scale"
    fi
  else
    scale=$y2_scale
    min=$y2_min
    if [ $y2_relative -gt 0 ];then
      min=$y2_min
      eval $(echo "$min $scale" | awk '{print "min="$1/$2}')
      ds_aps="($dm)/$scale-$min"
    else
      ds_aps="($dm)/$scale"
    fi
  fi
  if [ -z $scale ];then
    scale=1
  fi
  echo "ds_aps:$ds_aps"

  fm_str="$fm_str %-${space_12}s"
  data_str="$data_str,$ds_aps"

  index=$(($index+1))
done

eval $(echo "data_str=\"$data_str\"" | sed -e 's/\$/\\$/g')
eval $(echo "fm_str=\"$fm_str\"" | sed -e 's/ //g')
fm_str="\"$fm_str\n\""

echo "$data_str"
echo "$fm_str"

awk -F "$dm_flag" '{printf '$fm_str''$data_str'}' $log_file > $plot_file

#绘图数据
#awk -F "$dm_flag" '{printf "%-'$space_1's %-'$space_2's %-'$space_3's %-'$space_4's\n", ('$dm_stime'-'$min_t'), '$dm_cnnt'/10000, $5, ($5+$6+$7+$8+$9+$10+$11+$12)/8}' $log_file> $plot_file

#自动获取曲线颜色
#1-index 2-color_var
get_plot_color(){
  eval $(echo "$2=$1")
}

#1-index 2-x_var 3-y_var
get_plot_sin_info(){
  local index=$1
  local dm_y_x=""
  local dm_y=""
  local dm_y_nr="0"
  local y_x_n=0
  local lc_x=""
  local lc_y=""

  if [ $index -le 0 ];then
    echo "InnerError:index should gt 0"
    exit 1
  fi
  
  get_dm_num "dm_y1_nr" "$dm_y1"
  get_dm_num "dm_y2_nr" "$dm_y2"
  get_dm_num "dm_x_nr" "$dm_x"

  if [ $index -le $dm_y1_nr ];then
    offset=$index
    get_dm_num "y_x_n" "$dm_y1_x" 
    dm_y_nr=$dm_y1_nr
    dm_y_x="$dm_y1_x"
    #为name赋值
    eval $(echo "$4=\"${name_y1[$(($offset-1))]}\"")
  elif [ $index -le $(($dm_y1_nr+$dm_y2_nr)) ];then
    offset=$(($index-$dm_y1_nr))
    get_dm_num "y_x_n" "$dm_y2_x"
    dm_y_nr=$dm_y2_nr
    dm_y_x="$dm_y2_x"
    #为name赋值
    eval $(echo "$4=\"${name_y2[(($offset-1))]}\"")
  else
    echo "InnerError:--at get_plot_curv_src--"
    exit 1
  fi
      
  if [ -z $dm_y_x ];then
    eval $(echo "$2=1")
  else
    if [ $y_x_n -eq $dm_y_nr ];then
      eval $(echo "$dm_y_x" | awk -F "," '{print "lc_x="$'$offset'}')
      if [ $x -gt $dm_x_nr ];then
        echo "Error:check dm_y1_x config."
        dsusage 1
      else
        eval $(echo "$2= $lc_x")
      fi
    else
      echo "Error:check dm_y1_x config."
      dsusage 1
    fi
  fi
  lc_y=$(($index+$dm_x_nr))
  eval $(echo "$3=$lc_y")
}

#s生成曲线绘制命令
#每条曲线需要以下数据
#1、曲线名称
#2、对应x轴数据源
#3、对应Y轴数据源
#4、曲线颜色

#$1-cmd_var
get_plot_curv_cmd(){
  local index=1
  local x=0
  local y=0
  local cuv_num=$(($dm_y1_nr+$dm_y2_nr))
  local cmd_des=""

  while [ $index -le $cuv_num ]
  do
    if [ $index -le $dm_y1_nr ];then
      axis="x1y1"
      pt=$pty1
      ps=$ptsy1
      lw=$lwy1
    else
      axis="x1y2"
      pt=$pty2
      ps=$ptsy2
      lw=$lwy2
    fi
    get_plot_sin_info $index "x" "y" "name"
    get_plot_color $index "color"
    if [ -z "$cmd_des" ];then
      cmd_des="\\\"$plot_file\\\" u $x:$y w lp pt $pt ps $ps lc $color lw $lw axis $axis t \\\"$name\\\""
    else
      cmd_des="$cmd_des,\\\"$plot_file\\\" u $x:$y w lp pt $pt ps $ps lc $color lw $lw axis $axis t \\\"$name\\\""
    fi

    index=$(($index+1))
  done

  cmd_des="plot $cmd_des"
  echo "$cmd_des"
  eval $(echo "$1=\"$cmd_des\"")
  eval $(echo "dbg_echo \"$1=\$$1\"")
}

get_plot_curv_cmd "plot_cmd"
#$1-title 2-max_t 3-min_t 4-max_sp 5-min_sp 6-max-y2, 7-min-y2
set_plot_env(){
  x_len=$(($2-$3))
  plot_xlen=$(($x_len+1))

  #20个间隔
  plot_xnum=20
  plot_xtics=$(($plot_xlen+$plot_xnum))
  plot_xtics=$(($plot_xtics/$plot_xnum))

  plot_xrange_l=0
  plot_xrange_r=$(($plot_xlen+$plot_xnum))

  if [ $x_relative -lt 1 ];then
    plot_xrange_l=$3
    plot_xrange_r=$2
  fi

  echo "max_x:$2, min_x:$3 plot_xlen:$plot_xlen plot_xtics:$plot_xtics"

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
  
  if [ $y1_relative -lt 1 ];then
    plot_yrange_l=$5
    plot_yrange_r=$4
  else
    plot_yrange_l=0
    plot_yrange_r=$plot_ylen
  fi
  
  if [ $y2_relative -lt 1 ];then
    plot_y2range_l=$7
    plot_y2range_r=$6
  else
    plot_y2range_l=0
    plot_y2range_r=$plot_y2len
  fi

  #根据log文件名生成图片title
  plot_title=`basename $1`
  echo "title:$plot_title"

cat > $gnuplot_script << end_of_message
#set terminal $plot_term size 1300,600
set terminal pngcairo font "monospace" size 1300,600

set title "$plot_title:BasePoint:$base_line-RecLen:$rec_len"
set xrange [$plot_xrange_l : $plot_xrange_r]

set xtics $plot_xrange_l,$plot_xtics,$plot_xrange_r
set ytics $plot_yrange_l,$plot_ytics,$plot_yrange_r
set ytics nomirror
set y2tics $plot_y2range_l,$plot_y2tics,$plot_y2range_r
set grid
$plot_cmd
end_of_message
}

ax_max=$(($x_max+$x_scale))
ax_max=$(($ax_max/$x_scale))
ax_min=$(($x_min/$x_scale))

eval $(echo "$y1_max, $y1_scale" | awk '{print "ay1_max="$1/$2}')
eval $(echo "$y1_min, $y1_scale" | awk '{print "ay1_min="$1/$2}')
eval $(echo "$y2_max, $y2_scale" | awk '{print "ay2_max="$1/$2}')
eval $(echo "$y2_min, $y2_scale" | awk '{print "ay2_min="$1/$2}')

set_plot_env "$plot_name" $ax_max $ax_min $ay1_max $ay1_min $ay2_max $ay2_min 

gnuplot -p $gnuplot_script > $init_log_file-$y1_attr-$y2_attr-base-$base_line-len-$rec_len.png

exit 0

