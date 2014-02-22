#!/bin/bash

function aliases_monitor() {
	CONTAINER=$(get_container_id)
	CONTAINER_ROOT=$(get_container_root)
	CONTAINER_BASH_HISTORY="${CONTAINER_ROOT}/.bash_history"
	INOTIFY_OPTIONS='-m -r'

	while [[ ! "$(sudo inotifywait -e create $CONTAINER_ROOT 2> /dev/null)" =~ .*bash_history.* ]]
	do
		continue
	done
	log_command

	while sudo inotifywait -e modify $CONTAINER_BASH_HISTORY &> /dev/null
	do
		log_command
	done
}

function get_container_id() {
	CURRENT_LAST_CONTAINER=$(get_last_container)
	while [ "$CURRENT_LAST_CONTAINER" == "$(get_last_container)" ]
	do
		sleep 0.1
	done
	get_last_container
}

function get_container_root() {
	ROOT_DIR="$(docker inspect $CONTAINER | grep HostsPath | awk -F: '{print $2}' | sed -e 's|"||g' -e 's|/hosts||g' -e 's|,||g')/root"
	echo $ROOT_DIR
}

function get_last_container() {
	LAST_CONTAINER=$(docker ps | grep -v ^CONTAINER | head -n1 | awk '{print $1}')
	echo $LAST_CONTAINER
}

#function init_conf() {
#}

function log_command() {
	echo "RUN $(sudo tail -n1 $CONTAINER_BASH_HISTORY)" >> $DOCKERFILE
}


IMAGE=$1
export DOCKERFILE="Dockerfile.$(date +%Y%m%d%H%M)"
echo "FROM $IMAGE" > $DOCKERFILE

if [ $(id -u) -ne 0 ]
then
	echo "We need 'root' privileges for some actions!"
	if which sudo &> /dev/null
	then
		sudo ls > /dev/null
	else
		exit 0
	fi
fi

#init_conf &
#commit_monitor &
aliases_monitor &

docker run -t -i $IMAGE /bin/bash -c 'echo "shopt -s histappend; PROMPT_COMMAND=\"history -a;$PROMPT_COMMAND\"; rm .bash_history 2>/dev/null; history -c" >> ~/.bashrc; /bin/bash; rm ~/.bashrc'

# if Dockerfile only has the first line, remove it
if [ $(wc -l $DOCKERFILE | awk '{print $1}') -eq 1 ]
then 
	rm $DOCKERFILE
fi
