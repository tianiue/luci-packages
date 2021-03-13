#!/bin/bash
PATH="/usr/sbin:/usr/bin:/sbin:/bin"
binpath=$(uci get AdGuardHome.AdGuardHome.binpath)
if [ -z "$binpath" ]; then
	uci set AdGuardHome.AdGuardHome.binpath="/tmp/AdGuardHome/AdGuardHome"
	binpath="/tmp/AdGuardHome/AdGuardHome"
fi
[ ! -d ${binpath%/*} ] && mkdir -p ${binpath%/*}
upxflag=$(uci get AdGuardHome.AdGuardHome.upxflag 2>/dev/null)

check_if_already_running(){
	running_tasks="$(ps |grep "AdGuardHome" |grep "update_core" |grep -v "grep" |awk '{print $1}' |wc -l)"
	[ "${running_tasks}" -gt "2" ] && echo -e "\n已有一个任务正在运行,请等待其执行结束!"  && EXIT 2
}

check_wgetcurl(){
	which curl > /dev/null 2>&1 && downloader="curl -L -k --retry 2 --connect-timeout 20 -o" && return
	which wget-ssl > /dev/null 2>&1 && downloader="wget-ssl --no-check-certificate -t 2 -T 20 -O" && return
	[ -z "$1" ] && opkg update || (echo "未安装 opkg!" && EXIT 1)
	[ -z "$1" ] && (opkg remove wget wget-nossl --force-depends ; opkg install wget ; check_wgetcurl 1 ;return)
	[ "$1" == "1" ] && (opkg install curl ; check_wgetcurl 2 ; return)
	echo "未安装 curl 或 wget!" && EXIT 1
}
check_latest_version(){
	echo -e "\n执行文件存储路径: ${binpath%/*}"
	check_wgetcurl
	latest_ver="$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest 2>/dev/null | grep 'tag_name' | egrep -o 'v[0-9.]+')"
	if [ -z "$latest_ver" ]; then
		echo -e "\n检查最新版本失败,请稍后重试!"  && EXIT 1
	fi
	if [ -f $binpath ]; then
		now_ver="v$($binpath --version 2>/dev/null | egrep -o '[0-9]+[.][0-9.]+')"
	else
		now_ver="未知"
	fi
	echo -e "\n当前版本: ${now_ver},云端版本: ${latest_ver}"
	if [ ! "${latest_ver}" == "${now_ver}" ] || [ "$1" == "force" ]; then
		doupdate_core
	else
			echo -e "\n已是最新版本!" 
			if [ ! -z "$upxflag" ]; then
				filesize=$(ls -l $binpath | awk '{ print $5 }')
				if [ $filesize -gt 10240000 ]; then
					doupx
					mkdir -p /tmp/AdGuardHomeupdate/AdGuardHome > /dev/null 2>&1
					rm -f /tmp/AdGuardHomeupdate/AdGuardHome/${binpath##*/}
					echo -e "使用 UPX 压缩可能会花很长时间..."
					/tmp/upx-${upx_latest_ver}-${Arch_upx}_linux/upx $upxflag $binpath -o /tmp/AdGuardHomeupdate/AdGuardHome/${binpath##*/} > /dev/null 2>&1
					echo -e "\n压缩后的核心大小: $(awk 'BEGIN{printf "%.2fMB\n",'$((`ls -l $downloadbin | awk '{print $5}'`))'/1000000}')"
					echo -e "\n停止 AdGuardHome 服务..."
					/etc/init.d/AdGuardHome stop nobackup
					[ -f $binpath ] && rm -f $binpath
					mv -f /tmp/AdGuardHomeupdate/AdGuardHome/${binpath##*/} $binpath
					echo -e "\n重启 AdGuardHome 服务..."
					/etc/init.d/AdGuardHome restart
				fi
			fi
			EXIT 0
	fi
}
doupx(){
	GET_Arch
	upx_name="upx-${upx_latest_ver}-${Arch_upx}_linux.tar.xz"
	echo -e "开始下载 $upx_name ...\n"
	$downloader /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux.tar.xz "https://github.com/upx/upx/releases/download/v${upx_latest_ver}/$upx_name"
	if [ ! -e /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux.tar.xz ]; then
		echo -e "\n$upx_name 下载失败!\n" 
		EXIT 1
	else
		echo -e "\n$upx_name 下载成功!\n" 
	fi
	which xz > /dev/null 2>&1 || (opkg list | grep ^xz || opkg update > /dev/null 2>&1 && opkg install xz --force-depends) || (echo "软件包 xz 安装失败!" && EXIT 1)
	mkdir -p /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux
	xz -d -c /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux.tar.xz| tar -x -C "/tmp"
	[ ! -f /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux/upx ] && echo -e "\n$upx_name 解压失败!" && EXIT 1
}
doupdate_core(){
	mkdir -p "/tmp/AdGuardHomeupdate"
	rm -rf /tmp/AdGuardHomeupdate/* > /dev/null 2>&1
	GET_Arch
	grep -v "^#" /usr/share/AdGuardHome/links.txt > /tmp/run/AdHlinks.txt
	[ ! -s /tmp/run/AdHlinks.txt ] && echo -e "\n未选择任何链接,取消更新!" && EXIT 1
	while read link
	do
		eval link="$link"
		echo -e "文件名称:${link##*/}"
		echo -e "\n开始下载核心...\n" 
		$downloader /tmp/AdGuardHomeupdate/${link##*/} "$link" 2>&1
		if [ "$?" != "0" ]; then
			echo -e "\n下载失败,尝试使用其他链接更新..."
			rm -f /tmp/AdGuardHomeupdate/${link##*/}
		else
			local success=1
			break
		fi 
	done < "/tmp/run/AdHlinks.txt"
	rm -f /tmp/run/AdHlinks.txt
	[ -z "$success" ] && echo -e "\n核心下载失败!" && EXIT 1
	if [ "${link##*.}" == "gz" ]; then
		echo -e "\n解压 AdGuardHome ..."
		tar -zxf "/tmp/AdGuardHomeupdate/${link##*/}" -C "/tmp/AdGuardHomeupdate/"
		if [ ! -e "/tmp/AdGuardHomeupdate/AdGuardHome" ]; then
			echo "核心下载失败!" 
			rm -rf "/tmp/AdGuardHomeupdate" > /dev/null 2>&1
			EXIT 1
		fi
		downloadbin="/tmp/AdGuardHomeupdate/AdGuardHome/AdGuardHome"
	else
		downloadbin="/tmp/AdGuardHomeupdate/${link##*/}"
	fi
	chmod 777 $downloadbin
	echo -e "\n核心大小: $(awk 'BEGIN{printf "%.2fMB\n",'$((`ls -l $downloadbin | awk '{print $5}'`))'/1000000}')"
	if [ -n "$upxflag" ]; then
		doupx
		echo -e "使用 UPX 压缩可能会花很长时间..."
		echo -e "\n正在压缩 $downloadbin ..."
		/tmp/upx-${upx_latest_ver}-${Arch_upx}_linux/upx $upxflag $downloadbin > /dev/null 2>&1
		echo -e "\n压缩后的核心大小: $(awk 'BEGIN{printf "%.2fMB\n",'$((`ls -l $downloadbin | awk '{print $5}'`))'/1000000}')"
	fi
	echo -e "\n关闭 AdGuardHome 服务..." 
	/etc/init.d/AdGuardHome stop nobackup
	[ -f $binpath ] && rm -f $binpath
	echo -e "\n移动核心文件到 ${binpath%/*} ..."
	mv -f $downloadbin $binpath > /dev/null 2>&1
	if [ ! -f $binpath ]; then
		echo -e "执行文件移动失败!\n可能是设备空间不足导致,请使用UPX压缩,或更改[执行文件路径]为 /tmp/AdGuardHome" 
		EXIT 1
	fi
	chmod +x $binpath
	echo -e "\n重启 AdGuardHome 服务..."
	rm -f /tmp/upx*.tar.xz
	rm -rf /tmp/upx*	
	rm -rf /tmp/AdGuardHomeupdate
	/etc/init.d/AdGuardHome start
	echo -e "\nAdGuardHome 核心更新成功!" 
	EXIT 0
}
GET_Arch() {
	Archt="$(opkg info kernel | grep Architecture | awk -F "[ _]" '{print($2)}')"
	case $Archt in
	"i386")
		Arch="i386"
	;;
	"i686")
		Arch="i386"
		echo -e "i686 使用 $Arch 的核心可能会导致bug!" 
	;;
	"x86")
		Arch="amd64"
	;;
	"mipsel")
		Arch="mipsle_softfloat"
	;;
	"mips")
		Arch="mips_softfloat"
	;;
	"mips64el")
		Arch="mips64le_softfloat"
	;;
	"mips64")
		Arch="mips64_softfloat"
	;;
	"arm")
		Arch="arm"
	;;
	"armeb")
		Arch="armeb"
	;;
	"aarch64")
		Arch="arm64"
	;;
	*)
		echo -e "\nAdGuardHome 暂不支持当前设备架构[$Archt]!" 
		EXIT 1
	esac
	case $Archt in
	mipsel)
		Arch_upx="mipsel"
		upx_latest_ver="3.95"
	;;
	mips)
		Arch_upx="mips"
		upx_latest_ver="3.95"
	;;
	*)
		Arch_upx="$Arch"
		upx_latest_ver="$($downloader - https://api.github.com/repos/upx/upx/releases/latest 2>/dev/null | egrep 'tag_name' | egrep '[0-9.]+' -o 2>/dev/null)"
	
	esac
	echo -e "\n当前设备架构: $Arch\n"
}

EXIT(){
	rm -rf /var/run/update_core 2>/dev/null
	[ "$1" != "0" ] && touch /var/run/update_core_error
	exit $1
}
main(){
	check_if_already_running
	check_latest_version $1
}
	trap "EXIT 1" SIGTERM SIGINT
	touch /var/run/update_core
	rm - rf /var/run/update_core_error 2>/dev/null
	main $1
