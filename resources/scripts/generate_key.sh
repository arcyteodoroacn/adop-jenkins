#!/bin/bash
set -e

# Usage
usage() {
    echo "Usage:"
    echo "    ${0} -c <host> -p <port> -u <username> -w <password>"
    exit 1
}

# Constants
SLEEP_TIME=5
MAX_RETRY=10
BASE_JENKINS_KEY="adop/core/jenkins"
BASE_JENKINS_SSH_KEY="${BASE_JENKINS_KEY}/ssh"
BASE_JENKINS_SSH_PUBLIC_KEY_KEY="${BASE_JENKINS_SSH_KEY}/public_key"
JENKINS_HOME="/var/jenkins_home"
JENKINS_SSH_DIR="${JENKINS_HOME}/.ssh"
JENKINS_USER_CONTENT_DIR="${JENKINS_HOME}/userContent/"
GERRIT_ADD_KEY_PATH="accounts/self/sshkeys"
GERRIT_REST_AUTH="jenkins:jenkins"


while getopts "c:p:u:w:" opt; do
  case $opt in
    c)
      host=${OPTARG}
      ;;
    p)
      port=${OPTARG}
      ;;
    u)
      username=${OPTARG}
      ;;
    w)
      password=${OPTARG}
      ;;
    *)
      echo "Invalid parameter(s) or option(s)."
      usage
      ;;
  esac
done

if [ -z "${host}" ] || [ -z "${port}" ] || [ -z "${username}" ] || [ -z "${password}" ]; then
    echo "Parameters missing"
    usage
fi

echo "Generating Jenkins Key Pair"
if [ ! -d "${JENKINS_SSH_DIR}" ]; then mkdir -p "${JENKINS_SSH_DIR}"; fi
cd "${JENKINS_SSH_DIR}"

if [[ ! $(ls -A "${JENKINS_SSH_DIR}") ]]; then 
	ssh-keygen -t rsa -f 'id_rsa' -b 4096 -C "jenkins@adop-core" -N ''; 
	echo "Copy key to userContent folder"
	mkdir -p ${JENKINS_USER_CONTENT_DIR}
	rm -f ${JENKINS_USER_CONTENT_DIR}/id_rsa.pub
	cp ${JENKINS_SSH_DIR}/id_rsa.pub ${JENKINS_USER_CONTENT_DIR}/id_rsa.pub

	# Set correct permissions for Content Directory
	chown 1000:1000 "${JENKINS_USER_CONTENT_DIR}"
 
	public_key_val=$(cat ${JENKINS_SSH_DIR}/id_rsa.pub) 

	if [ $GIT_REPO == "gitlab" ]; then
		echo "Testing GitLab Connection"
			until curl -sL -w "\\n%{http_code}\\n" "http://gitlab/gitlab" -o /dev/null | grep "200" &> /dev/null
		do
			echo "GitLab unavailable, sleeping for ${SLEEP_TIME}"
			sleep "${SLEEP_TIME}"
		done

		echo "GitLab available, creating Jenkins user"
		GITLAB_ROOT_TOKEN="$(curl -X POST "http://gitlab/gitlab/api/v3/session?login=root&password=${GITLAB_ROOT_PASSWORD}" | python -c "import json,sys;obj=json.load(sys.stdin);print obj['private_token'];")"
		curl --header "PRIVATE-TOKEN: ${GITLAB_ROOT_TOKEN}" -X POST "http://gitlab/gitlab/api/v3/users?email=${GIT_GLOBAL_CONFIG_EMAIL}&name=jenkins&username=jenkins&password=${password}&provider=ldap&extern_uid=cn=jenkins,ou=people,${LDAP_ROOTDN}&admin=true&confirm=false"
		
		echo "Saving GitLab Root API Token"
		echo "${GITLAB_ROOT_TOKEN}" > ${JENKINS_USER_CONTENT_DIR}/gitlab_api_token.txt

		echo "Adding SSH key to GitLab Admin user"
		curl --header "PRIVATE-TOKEN: ${GITLAB_ROOT_TOKEN}" -X POST "http://gitlab/gitlab/api/v3/users/1/keys" --data-urlencode "title=jenkins@adop-core" --data-urlencode "key=${public_key_val}"
		
		echo "Uploading successful. Updating Jenkins GitLab connection configuration."
		cp /usr/share/jenkins/ref/com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig.xml /var/jenkins_home/
	fi
fi
# public_key_val=$(cat ${JENKINS_SSH_DIR}/id_rsa.pub)

# Set correct permissions on SSH Key
chown -R 1000:1000 "${JENKINS_SSH_DIR}"

# echo "Testing Gerrit Connection"
# until curl -sL -w "\\n%{http_code}\\n" "http://${host}:${port}/gerrit" -o /dev/null | grep "200" &> /dev/null
# do
#     echo "Gerrit unavailable, sleeping for ${SLEEP_TIME}"
#     sleep "${SLEEP_TIME}"
# done

# echo "Gerrit available, adding data"
# count=1
# until [ $count -ge ${MAX_RETRY} ]
# do
#   ret=$(curl -X POST --write-out "%{http_code}" --silent --output /dev/null \
#           -u "${username}:${password}" \
#           -H "Content-type: text/plain" \
#           --data "${public_key_val}" "http://${host}:${port}/gerrit/a/${GERRIT_ADD_KEY_PATH}")
#   [[ ${ret} -eq 201  ]] && break
#   count=$[$count+1]
#   echo "Unable to add jenkins public key on gerrit, response code ${ret}, retry ... ${count}"
#   sleep ${SLEEP_TIME}
# done