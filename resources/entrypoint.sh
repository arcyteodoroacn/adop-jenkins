#!/bin/bash

echo "Genarate JENKINS SSH KEY and add it to git repo"
if [ $ADOP_GERRIT_ENABLED = "true" ]; then
	host=$GERRIT_HOST_NAME
	port=$GERRIT_PORT
	username=$GERRIT_JENKINS_USERNAME
	password=$GERRIT_JENKINS_PASSWORD
	rm -rf /usr/share/jenkins/ref/jobs/GitLab_Load_Platform
elif [ $ADOP_GITLAB_ENABLED = "true" ]; then
	host=$GITLAB_HOST_NAME
	port=$GITLAB_PORT
	username=$GITLAB_JENKINS_USERNAME
	password=$GITLAB_JENKINS_PASSWORD
	rm -rf /usr/share/jenkins/ref/jobs/Load_Platform
fi
nohup /usr/share/jenkins/ref/adop\_scripts/generate_key.sh -c ${host} -p ${port} -u ${username} -w ${password} &
echo "start JENKINS"

chown -R 1000:1000 /var/jenkins_home
su jenkins -c /usr/local/bin/jenkins.sh
