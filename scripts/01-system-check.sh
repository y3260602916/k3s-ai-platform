#!/bin/bash
#系统环境检查脚本
#用途：快速查看系统基本信息

echo "====系统版本===="
lsb_release -a

echo "====内核版本===="
uname -r

echo "====CPU核心数===="
nproc

echo "====内存使用===="
free -h

echo "====磁盘使用===="
df -h /

echo "====当前用户===="
whoami

echo "====主机名===="
hostname

echo "====公网IP===="
curl -s ifconfig.me

echo ""
echo "====检查完成===="
