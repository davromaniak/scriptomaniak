#!/bin/bash
# example use : ./nginx_module_extractor.sh /home/cyril/tmp/nginx-1.1.19/debian
# Dependencies : bash 4, gawk, xmllint

# GET MODULE LIST FROM NGINX WIKI
dumppage=$(xmllint --html <(wget -O - -q http://wiki.nginx.org/Modules) 2> /dev/null)
eval $(
echo "declare -A arrmod;"
echo "arrmod=("
for tables in 3 4 5; do
	index=$(echo $tables | cut -d "_" -f1)
	arrname=$(echo $tables | cut -d "_" -f2 | tr -d "\r\n")
	c=1
	(echo "cat //table[$index]/tr/td[position()=1 or position()=last()]" | xmllint --html --shell <(echo $dumppage) | sed -e :a -e 's/<[^>]*>//g;/</N;//ba' | sed '/^$/d') 2> /dev/null | tail -n +2 | head -n -1 | 
	while read line; do
		if [ "x$line" == "x-------" ]; then
			c=$((c*-1))
		elif [ $c -lt 0 ]; then
			echo $couple | grep -q "__"
			if [ $? -eq 0 ]; then
				v=$(echo $couple | awk -F "__" '{print $1}')
				echo $couple | awk -F "__" '{print $2}' | awk -F "--" -v v="$v" '{ for (i=2;i<=NF;i++) { print "[--" $i "]=\42"v"\42"; }}'
			fi
			unset couple
			couple=$line
		elif [ $c -gt 0 ]; then
			echo $line | grep -q '^--'
	                if [ $? -eq 0 ]; then
				couple=${couple}__$line
			fi
		fi	
	done
done
echo ");"
)

# PARSING debian/rules file and displaying report
basedir=$1
echo "Module status for NGINX $(head -1 $basedir/changelog | sed -e "s/^.* (\(.*\)) .*$/\1/")"
for fl in $(grep -En '^config.status.[a-z]*:.*$' $basedir/rules | cut -d ":" -f1,2 | sed -e "s/config\.status\.//"); do
	unset bline eline flavour
	eval $(echo $fl | sed -e "s/^\(.*\):\(.*\)$/bline=\1;flavour=\2/")
	echo -e "\nnginx-${flavour} : "
	eline=$((bline + 1))
	while read line; do
		echo $line | grep -q 'CONFIGURE_OPTS' 
		if [ $? -eq 0 ]; then
			break
		else
			echo $line
		fi
	done < <(tail -n +$bline $basedir/rules | sed -e "s/\\\//g") | grep -E '^--(with|add).*$' | grep -Ev '^--with.*=.*$' | sed -e "s/\$(MODULESDIR)//" |
	while read confline; do
		unset act
		unset module
		eval $(echo $confline | sed -e "s/^--\([a-z]*\)-\(.*\)$/act=\1;module=\2/")
		cnf=$(echo $confline | tr -d "\r\n")
		if [ "x${arrmod[$cnf]}" == "x" ]; then
			displaymod=$cnf
		else
			displaymod=$(echo ${arrmod[$cnf]}" ("$cnf")")
		fi
		case "$act" in
		"with")
			echo "Enabled Module : $displaymod"
			;;
		"without")
			echo "Disabled Module : $displaymod"
			;;
		"add")
			modulepath=$(echo $cnf | cut -d "=" -f2 | cut -d "/" -f2)
			echo "Third Party Module : $modulepath"
			unset modulepath
			;;
		esac
	done | sort
done
