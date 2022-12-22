#!/bin/bash

udp_file='/etc/UDPserver'

repo_install(){
  link="https://raw.githubusercontent.com/rudi9999/ADMRufu/main/Repositorios/$VERSION_ID.list"
  case $VERSION_ID in
    8*|9*|10*|11*|16.04*|18.04*|20.04*|20.10*|21.04*|21.10*|22.04*) [[ ! -e /etc/apt/sources.list.back ]] && cp /etc/apt/sources.list /etc/apt/sources.list.back
                                                                    wget -O /etc/apt/sources.list ${link} &>/dev/null;;
  esac
}

time_reboot(){
  print_center -ama "RESTARTING VPS IN $1 SECONDS translated by Mushfiq"
  REBOOT_TIMEOUT="$1"
  
  while [ $REBOOT_TIMEOUT -gt 0 ]; do
     print_center -ne "-$REBOOT_TIMEOUT-\r"
     sleep 1
     : $((REBOOT_TIMEOUT--))
  done
  reboot
}

check_sistem(){
  fail(){
    clear
    echo -e "\e[1m\e[31m=====================================================\e[0m"
    echo -e "\e[1m\e[33meste script no es compatible con tu systema operativo\e[0m"
    echo -e "\e[1m\e[33m              Usa Ubuntu 20 o superior\e[0m"
    echo -e "\e[1m\e[31m=====================================================\e[0m"
    exit
  }
  VER=$(echo $VERSION_ID|awk -F '.' '{print $1}')
  if [[ ! $NAME = 'Ubuntu' ]]; then
    fail
  elif [[ $VER -lt 20 ]]; then
      fail
  fi
}

if [[ ! -e $udp_file/UDPserver.sh ]]; then
  source /etc/os-release
  check_sistem
	mkdir $udp_file
	chmod -R +x $udp_file
	wget -O $udp_file/module 'https://raw.githubusercontent.com/rudi9999/Herramientas/main/module/module' &>/dev/null
	chmod +x $udp_file/module
	source $udp_file/module
	wget -O $udp_file/limitador.sh "https://raw.githubusercontent.com/rudi9999/SocksIP-udpServer/main/limitador.sh" &>/dev/null
	chmod +x $udp_file/limitador.sh
	echo '/etc/UDPserver/UDPserver.sh' > /usr/bin/udp
	chmod +x /usr/bin/udp
	repo_install
	apt update -y && apt upgrade -y
	ufw disable
	apt remove netfilter-persistent -y
	cp $(pwd)/$0 $udp_file/UDPserver.sh
	chmod +x $udp_file/UDPserver.sh
	rm $(pwd)/$0 &> /dev/null
	title 'INSTALACION COMPLETA'
	print_center -ama "Use the command\nudp\nto run the menu"
	msg -bar
	time_reboot 10
fi

source $udp_file/module

ip_publica=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(wget -T 10 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com/")")

#======= CONFIGURACION CUENTAS SSH =======

data_user(){
	cat_users=$(cat "/etc/passwd"|grep 'home'|grep 'false'|grep -v 'syslog'|grep -v '::/'|grep -v 'hwid\|token')
	[[ -z "$(echo "${cat_users}"|head -1)" ]] && print_center -verm2 "NO REGISTERED SSH USERS" && return 1
	dat_us=$(printf '%-13s%-14s%-10s%-4s%-6s%s' 'User' 'Password' 'Date' 'Day' 'Limit' 'Status')
	msg -azu "  $dat_us"
	msg -bar

	i=1

  while read line; do
    u=$(echo "$line"|awk -F ':' '{print $1}')

    fecha=$(chage -l "$u"|sed -n '4p'|awk -F ': ' '{print $2}')

    mes_dia=$(echo $fecha|awk -F ',' '{print $1}'|sed 's/ //g')
    ano=$(echo $fecha|awk -F ', ' '{printf $2}'|cut -c 3-)
    us=$(printf '%-12s' "$u")

    pass=$(echo "$line"|awk -F ':' '{print $5}'|cut -d ',' -f2)
    [[ "${#pass}" -gt '12' ]] && pass="Desconosida"
    pass="$(printf '%-12s' "$pass")"

    unset stat
    if [[ $(passwd --status $u|cut -d ' ' -f2) = "P" ]]; then
      stat="$(msg -verd "ULK")"
    else
      stat="$(msg -verm2 "LOK")"
    fi

    Limit=$(echo "$line"|awk -F ':' '{print $5}'|cut -d ',' -f1)
    [[ "${#Limit}" = "1" ]] && Limit=$(printf '%2s%-4s' "$Limit") || Limit=$(printf '%-6s' "$Limit")

    echo -ne "$(msg -verd "$i")$(msg -verm2 "-")$(msg -azu "${us}") $(msg -azu "${pass}")"
    if [[ $(echo $fecha|awk '{print $2}') = "" ]]; then
      exp="$(printf '%8s%-2s' '[X]')"
      exp+="$(printf '%-6s' '[X]')"
      echo " $(msg -verm2 "$fecha")$(msg -verd "$exp")$(echo -e "$stat")" 
    else
      if [[ $(date +%s) -gt $(date '+%s' -d "${fecha}") ]]; then
        exp="$(printf '%-5s' "Exp")"
        echo " $(msg -verm2 "$mes_dia/$ano")  $(msg -verm2 "$exp")$(msg -ama "$Limit")$(echo -e "$stat")"
      else
        EXPTIME="$(($(($(date '+%s' -d "${fecha}") - $(date +%s))) / 86400))"
        [[ "${#EXPTIME}" = "1" ]] && exp="$(printf '%2s%-3s' "$EXPTIME")" || exp="$(printf '%-5s' "$EXPTIME")"
        echo " $(msg -verm2 "$mes_dia/$ano")  $(msg -verd "$exp")$(msg -ama "$Limit")$(echo -e "$stat")"
      fi
    fi
    let i++
  done <<< "$cat_users"
}

mostrar_usuarios(){
  for u in `cat /etc/passwd|grep 'home'|grep 'false'|grep -v 'syslog'|grep -v 'hwid'|grep -v 'token'|grep -v '::/'|awk -F ':' '{print $1}'`; do
    echo "$u"
  done
}
#======= limiter multi-login =====

limiter(){

	ltr(){
		clear
		msg -bar
		for i in `atq|awk '{print $1}'`; do
			if [[ ! $(at -c $i|grep 'limitador.sh') = "" ]]; then
				atrm $i
				sed -i '/limitador.sh/d' /var/spool/cron/crontabs/root
				print_center -verd "limiter stopped"
				enter
				return
			fi
		done
    print_center -ama "LIMITER SETUP"
    msg -bar
    print_center -ama "Block users when they exceed"
    print_center -ama "the maximum number of connections"
    msg -bar
    unset opcion
    while [[ -z $opcion ]]; do
      msg -nama " Run limitor every: "
      read opcion
      if [[ ! $opcion =~ $numero ]]; then
        del 1
        print_center -verm2 " Only numbers are allowed"
        sleep 2
        del 1
        unset opcion && continue
      elif [[ $opcion -le 0 ]]; then
        del 1
        print_center -verm2 "minimum time 1 minute"
        sleep 2
        del 1
        unset opcion && continue
      fi
      del 1
      echo -e "$(msg -nama " Ejecutar limitdor cada:") $(msg -verd "$opcion minutos")"
      echo "$opcion" > ${udp_file}/limit
    done

    msg -bar
    print_center -ama "Users blocked by the limiter\nwill be unlocked automatically\n(enter 0 for manual unlock)"
    msg -bar

    unset opcion
    while [[ -z $opcion ]]; do
      msg -nama " Desbloquear user cada: "
      read opcion
      if [[ ! $opcion =~ $numero ]]; then
        tput cuu1 && tput dl1
        print_center -verm2 " Only numbers are allowed"
        sleep 2
        tput cuu1 && tput dl1
        unset opcion && continue
      fi
      tput cuu1 && tput dl1
      [[ $opcion -le 0 ]] && echo -e "$(msg -nama " Desbloqueo:") $(msg -verd "manual")" || echo -e "$(msg -nama " Desbloquear user cada:") $(msg -verd "$opcion minutos")"
      echo "$opcion" > ${udp_file}/unlimit
    done
		nohup ${udp_file}/limitador.sh &>/dev/null &
    msg -bar
		print_center -verd "running limiter"
		enter	
	}

	l_exp(){
		clear
    	msg -bar
    	l_cron=$(cat /var/spool/cron/crontabs/root|grep -w 'limitador.sh'|grep -w 'ssh')
    	if [[ -z "$l_cron" ]]; then
      		echo '0 1 * * * /etc/UDPserver/limitador.sh --ssh' >> /var/spool/cron/crontabs/root
      		print_center -verd "scheduled expiration limiter\nwill be executed every day at 1 am\naccording to the time programmed on the server"
      		enter
      		return
    	else
      		sed -i '/limitador.sh --ssh/d' /var/spool/cron/crontabs/root
      		print_center -verm2 "expired limiter stopped" 
      		enter
      		return   
    	fi
	}

	log(){
		clear
		msg -bar
		print_center -ama "LIMITER REGISTRATION"
		msg -bar
		[[ ! -e ${udp_file}/limit.log ]] && touch ${udp_file}/limit.log
		if [[ -z $(cat ${udp_file}/limit.log) ]]; then
			print_center -ama "there is no limiter register"
			msg -bar
			sleep 2
			return
		fi
		msg -teal "$(cat ${udp_file}/limit.log)"
		msg -bar
		print_center -ama "►► Press enter to continue or ◄◄"
		print_center -ama "►► 0 to clear record ◄◄"
		read opcion
		[[ $opcion = "0" ]] && echo "" > ${udp_file}/limit.log
	}

	[[ $(cat /var/spool/cron/crontabs/root|grep -w 'limitador.sh'|grep -w 'ssh') ]] && lim_e=$(msg -verd "[ON]") || lim_e=$(msg -verm2 "[OFF]")

	clear
	msg -bar
	print_center -ama "LIMITADOR DE CUENTAS"
	msg -bar
	menu_func "MULTI-LOGIN LIMITER" "EXPIRED LIMITER $lim_e" "LIMITER LOG"
	back
	msg -ne " opcion: "
	read opcion
	case $opcion in
		1)ltr;;
		2)l_exp;;
		3)log;;
		0)return;;
	esac
}

# ======== detalles de clientes ====

detail_user(){
	clear
	usuarios_ativos=('' $(mostrar_usuarios))
	if [[ -z ${usuarios_ativos[@]} ]]; then
		msg -bar
		print_center -verm2 "No registered user"
		msg -bar
		sleep 3
		return
	else
		msg -bar
		print_center -ama "DETAILS OF THE USERS"
		msg -bar
	fi
	data_user
	msg -bar
	enter
}

#======== bloquear clientes ======

block_user(){
  clear
  usuarios_ativos=('' $(mostrar_usuarios))
  msg -bar
  print_center -ama "LOCK/UNLOCK USERS"
  msg -bar
  data_user
  back

  print_center -ama "Write or Select a User"
  msg -bar
  unset selection
  while [[ ${selection} = "" ]]; do
    echo -ne "\033[1;37m Seleccione: " && read selection
    del 1
  done
  [[ ${selection} = "0" ]] && return
  if [[ ! $(echo "${selection}" | egrep '[^0-9]') ]]; then
    usuario_del="${usuarios_ativos[$selection]}"
  else
    usuario_del="$selection"
  fi
  [[ -z $usuario_del ]] && {
    msg -verm "Error, Usuario Invalido"
    msg -bar
    return 1
  }
  [[ ! $(echo ${usuarios_ativos[@]}|grep -w "$usuario_del") ]] && {
    msg -verm "Error, Usuario Invalido"
    msg -bar
    return 1
  }

  msg -nama "   $(fun_trans "Usuario"): $usuario_del >>>> "

  if [[ $(passwd --status $usuario_del|cut -d ' ' -f2) = "P" ]]; then
    pkill -u $usuario_del &>/dev/null
    droplim=`droppids|grep -w "$usuario_del"|awk '{print $2}'` 
    kill -9 $droplim &>/dev/null
    usermod -L $usuario_del &>/dev/null
    sleep 2
    msg -verm2 "Bloqueado"
  else
  	usermod -U $usuario_del
  	sleep 2
  	msg -verd "Desbloqueado"
  fi
  msg -bar
  sleep 3
}

#========renovar cliente =========

renew_user_fun(){
  #nome dias
  datexp=$(date "+%F" -d " + $2 days") && valid=$(date '+%C%y-%m-%d' -d " + $2 days")
  if chage -E $valid $1 ; then
  	print_center -ama "Usuario Renovado Con Exito"
  else
  	print_center -verm "Error, Usuario no Renovado"
  fi
}

renew_user(){
  clear
  usuarios_ativos=('' $(mostrar_usuarios))
  msg -bar
  print_center -ama "RENOVAR USUARIOS"
  msg -bar
  data_user
  back

  print_center -ama "Escriba o seleccione un Usuario"
  msg -bar
  unset selection
  while [[ -z ${selection} ]]; do
    msg -nazu "Seleccione una Opcion: " && read selection
    del 1
  done

  [[ ${selection} = "0" ]] && return
  if [[ ! $(echo "${selection}" | egrep '[^0-9]') ]]; then
    useredit="${usuarios_ativos[$selection]}"
  else
    useredit="$selection"
  fi

  [[ -z $useredit ]] && {
    msg -verm "Error, Usuario Invalido"
    msg -bar
    sleep 3
    return 1
  }

  [[ ! $(echo ${usuarios_ativos[@]}|grep -w "$useredit") ]] && {
    msg -verm "Error, Usuario Invalido"
    msg -bar
    sleep 3
    return 1
  }

  while true; do
    msg -ne "Nuevo Tiempo de Duracion de: $useredit"
    read -p ": " diasuser
    if [[ -z "$diasuser" ]]; then
      echo -e '\n\n\n'
      err_fun 7 && continue
    elif [[ "$diasuser" != +([0-9]) ]]; then
      echo -e '\n\n\n'
      err_fun 8 && continue
    elif [[ "$diasuser" -gt "360" ]]; then
      echo -e '\n\n\n'
      err_fun 9 && continue
    fi
    break
  done
  msg -bar
  renew_user_fun "${useredit}" "${diasuser}"
  msg -bar
  sleep 3
}

#======== remove client =========

droppids(){
  port_dropbear=`ps aux|grep 'dropbear'|awk NR==1|awk '{print $17;}'`
  log=/var/log/auth.log
  loginsukses='Password auth succeeded'
  pids=`ps ax|grep 'dropbear'|grep " $port_dropbear"|awk -F " " '{print $1}'`
  for pid in $pids; do
    pidlogs=`grep $pid $log |grep "$loginsukses" |awk -F" " '{print $3}'`
    i=0
    for pidend in $pidlogs; do
      let i=i+1
    done
    if [ $pidend ];then
       login=`grep $pid $log |grep "$pidend" |grep "$loginsukses"`
       PID=$pid
       user=`echo $login |awk -F" " '{print $10}' | sed -r "s/'/ /g"`
       waktu=`echo $login |awk -F" " '{print $2"-"$1,$3}'`
       while [ ${#waktu} -lt 13 ]; do
           waktu=$waktu" "
       done
       while [ ${#user} -lt 16 ]; do
           user=$user" "
       done
       while [ ${#PID} -lt 8 ]; do
           PID=$PID" "
       done
       echo "$user $PID $waktu"
    fi
	done
}

rm_user(){
  pkill -u $1
  droplim=`droppids|grep -w "$1"|awk '{print $2}'` 
  kill -9 $droplim &>/dev/null
  userdel --force "$1" &>/dev/null
  msj=$?
}

remove_user(){
	clear
	usuarios_ativos=('' $(mostrar_usuarios))
	msg -bar
	print_center -ama "REMOVE USERS"
	msg -bar
	data_user
	back

	print_center -ama "Write or Select a User"
	msg -bar
	unset selection
	while [[ -z ${selection} ]]; do
		msg -nazu "Seleccione Una Opcion: " && read selection
		tput cuu1 && tput dl1
	done
	[[ ${selection} = "0" ]] && return
	if [[ ! $(echo "${selection}" | egrep '[^0-9]') ]]; then
		usuario_del="${usuarios_ativos[$selection]}"
	else
		usuario_del="$selection"
	fi
	[[ -z $usuario_del ]] && {
		msg -verm "Error, Usuario Invalido"
		msg -bar
		return 1
	}
	[[ ! $(echo ${usuarios_ativos[@]}|grep -w "$usuario_del") ]] && {
		msg -verm "Error, Usuario Invalido"
		msg -bar
		return 1
	}

	print_center -ama "Selected User: $usuario_del"
	rm_user "$usuario_del"
  if [[ $msj = 0 ]] ; then
    print_center -verd "[Removed]"
  else
    print_center -verm "[Not removed]"
  fi
  enter
}

#========crear cliente =============
add_user(){
  Fecha=`date +%d-%m-%y-%R`
  [[ $(cat /etc/passwd |grep $1: |grep -vi [a-z]$1 |grep -v [0-9]$1 > /dev/null) ]] && return 1
  valid=$(date '+%C%y-%m-%d' -d " +$3 days")
  osl_v=$(openssl version|awk '{print $2}')
  osl_v=${osl_v:0:5}
  if [[ $osl_v = '1.1.1' ]]; then
    pass=$(openssl passwd -6 $2)
  else
    pass=$(openssl passwd -1 $2)
  fi
  useradd -M -s /bin/false -e ${valid} -K PASS_MAX_DAYS=$3 -p ${pass} -c $4,$2 $1 &>/dev/null
  msj=$?
}

new_user(){
  clear
  usuarios_ativos=('' $(mostrar_usuarios))
  msg -bar
  print_center -ama "CREATE CLIENT"
  msg -bar
  data_user
  back

  while true; do
    msg -ne " Nombre Usuario: "
    read nomeuser
    nomeuser="$(echo $nomeuser|sed 'y/áÁàÀãÃâÂéÉêÊíÍóÓõÕôÔúÚñÑçÇªº/aAaAaAaAeEeEiIoOoOoOuUnNcCao/')"
    nomeuser="$(echo $nomeuser|sed -e 's/[^a-z0-9 -]//ig')"
    if [[ -z $nomeuser ]]; then
      err_fun 1 && continue
    elif [[ "${nomeuser}" = "0" ]]; then
      return
    elif [[ "${#nomeuser}" -lt "4" ]]; then
      err_fun 2 && continue
    elif [[ "${#nomeuser}" -gt "12" ]]; then
      err_fun 3 && continue
    elif [[ "$(echo ${usuarios_ativos[@]}|grep -w "$nomeuser")" ]]; then
      err_fun 14 && continue
    fi
    break
  done

  while true; do
    msg -ne " Contraseña De Usuario"
    read -p ": " senhauser
    senhauser="$(echo $senhauser|sed 'y/áÁàÀãÃâÂéÉêÊíÍóÓõÕôÔúÚñÑçÇªº/aAaAaAaAeEeEiIoOoOoOuUnNcCao/')"
    if [[ -z $senhauser ]]; then
      err_fun 4 && continue
    elif [[ "${#senhauser}" -lt "4" ]]; then
      err_fun 5 && continue
    elif [[ "${#senhauser}" -gt "12" ]]; then
      err_fun 6 && continue
    fi
    break
  done

  while true; do
    msg -ne " Tiempo de Duracion"
    read -p ": " diasuser
    if [[ -z "$diasuser" ]]; then
      err_fun 7 && continue
    elif [[ "$diasuser" != +([0-9]) ]]; then
      err_fun 8 && continue
    elif [[ "$diasuser" -gt "360" ]]; then
      err_fun 9 && continue
    fi 
    break
  done

  while true; do
    msg -ne " Limite de Conexion"
    read -p ": " limiteuser
    if [[ -z "$limiteuser" ]]; then
      err_fun 11 && continue
    elif [[ "$limiteuser" != +([0-9]) ]]; then
      err_fun 12 && continue
    elif [[ "$limiteuser" -gt "999" ]]; then
      err_fun 13 && continue
    fi
    break
  done

  add_user "${nomeuser}" "${senhauser}" "${diasuser}" "${limiteuser}"
  clear
  msg -bar
  if [[ $msj = 0 ]]; then
    print_center -verd "User Created Successfully"
  else
    print_center -verm2 "Error, User not created"
    enter
    return 1
  fi
  msg -bar
  msg -ne " IP del Servidor: " && msg -ama "    $ip_publica"
  msg -ne " Usuario: " && msg -ama "            $nomeuser"
  msg -ne " Contraseña: " && msg -ama "         $senhauser"
  msg -ne " Dias de Duracion: " && msg -ama "   $diasuser"
  msg -ne " Limite de Conexion: " && msg -ama " $limiteuser"
  msg -ne " Fecha de Expiracion: " && msg -ama "$(date "+%F" -d " + $diasuser days")"
  enter
}

#=======================================
#======= CONFIGURACION UDPSERVER ========

download_udpServer(){
	msg -nama '        Descargando binario UDPserver .....'
	if wget -O /usr/bin/udpServer 'https://bitbucket.org/iopmx/udprequestserver/downloads/udpServer' &>/dev/null ; then
		chmod +x /usr/bin/udpServer
		msg -verd 'OK'
	else
		msg -verm2 'fail'
		rm -rf /usr/bin/udpServer*
	fi
}

make_service(){
	ip_nat=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n 1p)
	interfas=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}'|grep "$ip_nat"|awk {'print $NF'})
	ip_publica=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(wget -T 10 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com/")")

	#ip_nat=$(fun_ip nat)
	#interfas=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}'|grep "$ip_nat"|awk {'print $NF'})
	#ip_publica=$(fun_ip)

cat <<EOF > /etc/systemd/system/UDPserver.service
[Unit]
Description=UDPserver Service by @Rufu99
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/bin/udpServer -ip=$ip_publica -net=$interfas$Port -mode=system
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target6
EOF

	msg -nama '        Ejecutando servicio UDPserver .....'
	systemctl start UDPserver &>/dev/null
	if [[ $(systemctl is-active UDPserver) = 'active' ]]; then
		msg -verd 'OK'
		systemctl enable UDPserver &>/dev/null
	else
		msg -verm2 'fail'
	fi
}

exclude(){
  title 'Excluir puertos UDP'
  print_center -ama 'UDPserver covers the full range of ports.'
  print_center -ama 'you can exclude UDP ports'
  msg -bar3
  print_center -ama 'Examples of ports to exclude:'
  print_center -ama 'dnstt (slowdns) udp 53 5300'
  print_center -ama 'wireguard udp 51820'
  print_center -ama 'openvpn udp 1194'
  msg -bar
  print_center -verd 'enter the ports separated by spaces'
  print_center -verd 'Example: 53 5300 51820 1194'
  msg -bar3
  in_opcion_down 'digita puertos o enter saltar'
  del 2
  tmport=($opcion)
  for (( i = 0; i < ${#tmport[@]}; i++ )); do
    num=$((${tmport[$i]}))
    if [[ $num -gt 0 ]]; then
      echo "$(msg -ama " Puerto a excluir >") $(msg -azu "$num") $(msg -verd "OK")"
      Port+=" $num"
    else
      msg -verm2 " No es un puerto > ${tmport[$i]}?"
      continue
    fi
  done

  if [[ -z $Port ]]; then
    unset Port
    print_center -ama 'no ports excluded'
  else
    Port=" -exclude=$(echo "$Port"|sed "s/ /,/g"|sed 's/,//')"
  fi
  msg -bar3
}

install_UDP(){
	title 'INSTALACION UDPserver'
  exclude
	download_udpServer
	if [[ $(type -p udpServer) ]]; then
		make_service
		msg -bar3
		if [[ $(systemctl is-active UDPserver) = 'active' ]]; then
			print_center -verd 'installation complete'
		else
			print_center -verm2 'fail to run service'
		fi
	else
		echo
		print_center -ama 'Failed to download udpServer binary'
	fi
	enter	
}

uninstall_UDP(){
	title 'DESINTALADOR UDPserver'
	read -rp " $(msg -ama "QUIERE DISINSTALAR UDPserver? [S/N]:") " -e -i S UNINS
	[[ $UNINS != @(S|s) ]] && return
	systemctl stop UDPserver &>/dev/null
	systemctl disable UDPserver &>/dev/null
	rm -rf /etc/systemd/system/UDPserver.service
	rm -rf /usr/bin/udpServer
	del 1
	print_center -ama "full uninstall!"
	enter
}

reset(){
	if [[ $(systemctl is-active UDPserver) = 'active' ]]; then
		systemctl stop UDPserver &>/dev/null
		systemctl disable UDPserver &>/dev/null
		print_center -ama 'UDPserver arrested!'
	else
		systemctl start UDPserver &>/dev/null
		if [[ $(systemctl is-active UDPserver) = 'active' ]]; then
			systemctl enable UDPserver &>/dev/null
			print_center -verd 'UDPserver initiated!'
		else
			print_center -verm2 'fail to start UDPserver!'
		fi	
	fi
	enter
}

#==========================================

QUIC_SCRIPT(){
	title 'DESINSTALADOR SCRIPT UDPserver'
	read -rp " $(msg -ama "QUIERE DISINSTALAR EL SCRIPT UDPserver? [S/N]:") " -e -i N UNINS
	[[ $UNINS != @(S|s) ]] && return
	systemctl disable UDPserver &>/dev/null
	systemctl stop UDPserver &>/dev/null
	rm /etc/systemd/system/UDPserver.service
	rm /usr/bin/udpServer
	rm /usr/bin/udp
	rm -rf $udp_file
	title 'DESINSTALACION COMPLETA'
	time_reboot 10
}

add_exclude(){
  title 'Excluir puertos UDP'
  print_center -ama 'UDPserver cubre el rango total de puertos.'
  print_center -ama 'puedes excluir puertos UDP'
  msg -bar3
  print_center -ama 'Ejemplos de puertos a excluir:'
  print_center -ama 'dnstt (slowdns) udp 53 5300'
  print_center -ama 'wireguard udp 51820'
  print_center -ama 'openvpn udp 1194'
  msg -bar
  print_center -verd 'ingresa los puertos separados por espacios'
  print_center -verd 'Ejemplo: 53 5300 51820 1194'
  in_opcion_down 'Ingresa puertos o enter para canselar'
  del 4
  tmport=($opcion)
  unset Port
  for (( i = 0; i < ${#tmport[@]}; i++ )); do
    num=$((${tmport[$i]}))
    if [[ $num -gt 0 ]]; then
      echo "$(msg -ama " Puerto a excluir >") $(msg -azu "$num") $(msg -verd "OK")"
      Port+=" $num"
    else
      msg -verm2 " No es un puerto > ${tmport[$i]}?"
      continue
    fi
  done
  if [[ $Port = "" ]]; then
    unset Port
    print_center -ama 'no ports excluded'
  else
    exclude=$(cat /etc/systemd/system/UDPserver.service|grep 'exclude')
    if systemctl is-active UDPserver &>/dev/null; then
      systemctl stop UDPserver &>/dev/null
      systemctl disable UDPserver &>/dev/null
      iniciar=1
    fi
    if [[ -z $exclude ]]; then
      Port=" -exclude=$(echo "$Port"|sed "s/ /,/g"|sed 's/,//')"
      sed -i "s/ -mode/$Port -mode/" /etc/systemd/system/UDPserver.service
    else
      exclude_port=$(echo $exclude|awk '{print $4}'|cut -d '=' -f2)
      Port="-exclude=$exclude_port$(echo "$Port"|sed "s/ /,/g")"
      sed -i "s/-exclude=$exclude_port/$Port/" /etc/systemd/system/UDPserver.service
    fi
    if [[ $iniciar = 1 ]]; then
      systemctl start UDPserver &>/dev/null
      systemctl enable UDPserver &>/dev/null
    fi
  fi
  enter
}

quit_exclude(){
  title 'QUITAR PUERTO DE EXCLUCION'
  exclude=$(cat /etc/systemd/system/UDPserver.service|grep 'exclude'|awk '{print $4}')
  ports=($port)
  for (( i = 0; i < ${#ports[@]}; i++ )); do
    a=$(($i+1))
    echo "             $(msg -verd "[$a]") $(msg -verm2 '>') $(msg -azu "${ports[$i]}")"
  done
  if [[ ! ${#ports[@]} = 1 ]]; then
    let a++
    msg -bar
    echo "             $(msg -verd "[0]") $(msg -verm2 ">") $(msg -bra "\033[1;41mVOLVER")  $(msg -verd "[$a]") $(msg -verm2 '> QUITAR TODOS')"
    msg -bar
  else
    msg -bar
    echo "             $(msg -verd "[0]") $(msg -verm2 ">") $(msg -bra "\033[1;41mVOLVER")"
    msg -bar
  fi
  opcion=$(selection_fun $a)
  [[ $opcion = 0 ]] && return
  if systemctl is-active UDPserver &>/dev/null; then
    systemctl stop UDPserver &>/dev/null
    systemctl disable UDPserver &>/dev/null
    iniciar=1
  fi
  if [[ $opcion = $a ]]; then
    sed -i "s/$exclude //" /etc/systemd/system/UDPserver.service
    print_center -ama 'Removed all excluded ports'
  else
    let opcion--
    unset Port
    for (( i = 0; i < ${#ports[@]}; i++ )); do
      [[ $i = $opcion ]] && continue
      echo "$(msg -ama " Puerto a excluir >") $(msg -azu "${ports[$i]}") $(msg -verd "OK")"
      Port+=" ${ports[$i]}"
    done
    Port=$(echo $Port|sed 's/ /,/g')
    sed -i "s/$exclude/-exclude=$Port/" /etc/systemd/system/UDPserver.service
  fi
  if [[ $iniciar = 1 ]]; then
    systemctl start UDPserver &>/dev/null
    systemctl enable UDPserver &>/dev/null
  fi
  enter
}

menu_udp(){
	title 'SCRIPT Translated By @mushfiq.tceh'
	print_center -ama 'UDPserver Binary by team newtoolsworks'
	print_center -ama 'UDPclient Android SocksIP'
	msg -bar
  
	if [[ $(type -p udpServer) ]]; then
    port=$(cat /etc/systemd/system/UDPserver.service|grep 'exclude')
    if [[ ! $port = "" ]]; then
      port=$(echo $port|awk '{print $4}'|cut -d '=' -f2|sed 's/,/ /g')
      print_center -ama "EXCLUDED PORTS $port"
      msg -bar
    fi
    ram=$(printf '%-8s' "$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')")
    cpu=$(printf '%-1s' "$(top -bn1 | awk '/Cpu/ { cpu = "" 100 - $8 "%" }; END { print cpu }')")
    echo " $(msg -verd 'IP:') $(msg -azu "$ip_publica")  $(msg -verd 'Ram:') $(msg -azu "$ram") $(msg -verd 'CPU:') $(msg -azu "$cpu")"
    msg -bar

		if [[ $(systemctl is-active UDPserver) = 'active' ]]; then
			estado="\e[1m\e[32m[ON]"
		else
			estado="\e[1m\e[31m[OFF]"
		fi
		echo " $(msg -verd "[1]") $(msg -verm2 '>') $(msg -verm2 'DESINSTALAR UDPserver')"
		echo -e " $(msg -verd "[2]") $(msg -verm2 '>') $(msg -azu 'START/STOP UDPserver') $estado"
    echo " $(msg -verd "[3]") $(msg -verm2 '>') $(msg -azu 'REOMOVER SCRIPT')"
		msg -bar3
		echo " $(msg -verd "[4]") $(msg -verm2 '>') $(msg -verd 'CREATE CLIENT')"
		echo " $(msg -verd "[5]") $(msg -verm2 '>') $(msg -verm2 'REMOVE CLIENT')"
		echo " $(msg -verd "[6]") $(msg -verm2 '>') $(msg -ama 'RENEW CLIENT')"
		echo " $(msg -verd "[7]") $(msg -verm2 '>') $(msg -azu 'LOCK/UNLOCK CLIENT')"
		echo " $(msg -verd "[8]") $(msg -verm2 '>') $(msg -blu 'CLIENT DETAILS')"
		echo " $(msg -verd "[9]") $(msg -verm2 '>') $(msg -azu 'LIMITED ACCOUNTS')"
		msg -bar3
    print_center -ama 'PORT EXCLUSION'
    msg -bar3
    echo " $(msg -verd "[10]") $(msg -verm2 '>') $(msg -verd 'ADD PORT TO EXCLUSION LIST')"
		num=10
    if [[ ! $port = "" ]]; then
      echo " $(msg -verd "[11]") $(msg -verm2 '>') $(msg -verm2 'QUITAR PUERTO A LISTA DE EXCLUSION')"
      num=11
    fi
    a=x; b=1
	else
		echo " $(msg -verd "[1]") $(msg -verm2 '>') $(msg -verd 'INSTALL UDPserver')"
		num=1; a=1; b=x
	fi
	back
	opcion=$(selection_fun $num)

	case $opcion in
		$a)install_UDP;;
		$b)uninstall_UDP;;
		2)reset;;
    3)QUIC_SCRIPT;;
		4)new_user;;
		5)remove_user;;
		6)renew_user;;
		7)block_user;;
		8)detail_user;;
		9)limiter;;
    10)add_exclude;;
    11)quit_exclude;;
		0)return 1;;
	esac
}

while [[  $? -eq 0 ]]; do
  menu_udp
done
