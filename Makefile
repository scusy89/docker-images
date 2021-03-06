# Makefile to build and run Docker Images for the Serene Project
# 
# Maintainer: Johannes Lahann
# Last edit: 05.01.2016
# 
# Tipp: It makes sense to enable manuel marker for folding to view/edit this
# file. E.g. you can use vim which supports it out of the box.
# Included services:
#   Maintannance and management
#   - confluence
#   - jira
#   - jenkins
#   - phpmyadmin
#   - sonaqube
#   - postgresql 
#   Proxy
#   - nginxproxy
#   Projects
#   - wildfly
#   - mysql
#   - spark (currently included in wildfly docker)
#   - kafka
#   - elasticsearch
# 
# Versioning 
# - http://github.com/scusy89/docker-images
# - http://svn.dfki.de/SERENE/docker
#
# User Guide
# - confluence.willie.iwi.uni-sb.de

# Quick Guide: {{{
#   Step 1: Stop and remove pending services:
#   - docker ps (lists running docker container)
#   - docker ps -a (lists all existing docker container)
#
#   Step 2: Stop and remove pending container 
#   Important!!! : You should not remove the data container!!!!
#   - docker stop wildfly (stops wildfly container)
#   - docker rm wildfly (removes wildfly container)
#
#   Step 3: Build
#   - make wildfly-build (builds the wildfly-container)
#
#   Step 4: Run 
#    - make wildfly-run (runs the wildfly-container)
#
# One Trick Pony (replaces all steps)
#   Deployment:
#   - make development-setup (only once at setup time)
#   - make development-run (only once at setup time)
#   - make development-restart
#   - make development-start
#   - make development-stop
#   Server:
#   - make server-setup (only once at setup time)
#   - make server-run (only once at setup time)
#   - make server-restart
#   - make server-start
#   - make server-stop
#
# Other helpful stuff:
#  - docker exec -it wildfly bash (runs a bash shell on wildfly container)
#  - docker logs -f wildfly (tails the wildfly container log)
#  - make all-stop (stops all existing container)
# }}}

# Global Vars

maintainer=serenedocker/
.DEFAULT_GOAL := run
rootDir=$(shell pwd)
dataDir=  $(HOME)/sereneDataFolder
backupDir=  $(HOME)/sereneBackup

# Server: {{{1
# ----------------------------------------------------------------------------

# Setup for Servers: (only once)
server-setup: setup-base management-build proxy-build projects-build 

# Stop server services
server-stop: all-stop 

# Run server services (This includes creating the container)
server-run: projects-run

# Start server services
server-start: proxy-start projects-start management-start

# Restart server services
server-restart: server-stop server-start

# Local development: {{{1
# ----------------------------------------------------------------------------
#
# Setup for development: (only once)
development-setup: setup-base projects-build 

# Stop development services
development-stop: projects-stop

# Start development services
development-start:  projects-start

# Run development services (This includes creating the docker container
development-run:  projects-run


# Restart development services
development-restart: development-stop development-start


# Helpers: {{{1
# ----------------------------------------------------------------------------

# Initial build  used once
setup-base: 
	-mkdir '$(backupDir)'
	chmod  777 '$(backupDir)'
	$(data-build)
	$(data-run)

docker-ps:
	docker ps -aq
all-stop:
	docker stop $$(docker ps -a -q)
z-all-remove:
	docker rm $$(docker ps -aq)

# Tmux: {{{2
tmux-run-split:
	tmux split-window -p 33 -h '$(mysql-run)' 
	tmux split-window -p 66 -v '$(elastic-run)'
	sleep 1
	tmux split-window  -v '$(wildfly-run)'
	tmux rotate -D
	tmux select-pane -t 2

tmux-run:	
	tmux new-window -n mysql '$(mysql-run)' 
	tmux new-window -n kafka '$(kafka-run)' 
	tmux new-window -n elastic '$(elastic-run)'
	sleep 1
	tmux new-window  -n wildfly '$(wildfly-run)'

# Management {{{2

management-build: postgresql-build jira-build confluence-build jenkins-build

management-run: postgresql-run jira-run confluence-run jenkins-run

management-start:
	docker start postgresql
	docker start jira
	docker start confluence
	docker start jenkins

management-remove:
	docker rm postgresql jira confluence jenkins

management-stop:
	docker stop postgresql jira confluence jenkins

# Proxy {{{2
proxy-build: nginxproxy-build

proxy-run: nginxproxy-run

proxy-start:
	docker start nginxproxy

proxy-remove: 
	docker rm nginxproxy

proxy-stop:
	docker stop nginxproxy

# Projects {{{2
projects-build : mysql-build elastic-build kafka-build wildfly-build

projects-start: 
	docker start mysql
	docker start elastic
	docker start kafka
	docker start wildfly



projects-run: mysql-run elastic-run kafka-run wildfly-run


projects-remove:
	docker rm mysql elastic kafka wildfly 

projects-stop:
	-docker stop mysql elastic kafka wildfly 

# Data: {{{1
# ----------------------------------------------------------------------------

data=$(maintainer)data
date=$(shell date +%Y-%m-%d_%H_%M)
data-build:
	docker build -t $(data) data 

data-run= docker run  --name data $(data)
data-run:
	$(data-run)

data-backup-postgresql= docker run --volumes-from data -v $(backupDir):/backup ubuntu tar cvf /backup/postgresql_backup_$(date).tar /var/lib/postgresql
data-backup-mysql= docker run --volumes-from data -v $(backupDir):/backup ubuntu tar cvf /backup/mysql_backup_$(date).tar /var/lib/mysql
data-backup-kafka= docker run --volumes-from data -v $(backupDir):/backup ubuntu tar cvf /backup/kafka_backup_$(date).tar /tmp/kafka-logs
data-backup-elasticsearch= docker run --volumes-from data -v $(backupDir):/backup ubuntu tar cvf /backup/elasticsearch_backup_$(date).tar /usr/share/elasticsearch/data
data-backup-jenkins= docker run --volumes-from data -v $(backupDir):/backup ubuntu tar cvf /backup/jenkins_backup_$(date).tar /var/jenkins_home
data-backup-jira= docker run --volumes-from data -v $(backupDir):/backup ubuntu tar cvf /backup/jira_backup_$(date).tar /var/atlassian/jira
data-backup-confluence= docker run --volumes-from data -v $(backupDir):/backup ubuntu tar cvf /backup/confluence_backup_$(date).tar /var/atlassian/confluence
data-backup= docker run --volumes-from data -v $(backupDir):/backup ubuntu tar cvf /backup/backup_$(date).tar /shared/
data-backup-new: 
	$(data-backup)
data-backup:
	$(data-backup-postgresql)
	$(data-backup-mysql)
	$(data-backup-kafka)
	$(data-backup-elasticsearch)
	$(data-backup-jenkins)
	$(data-backup-jira)
	$(data-backup-confluence)

data-rm: docker rm data

# Wildfly: {{{1
# ----------------------------------------------------------------------------
sparkJobsDir=  "$(shell dirname "$(shell pwd)")/development/main/SparkJobs"
wildfly=$(maintainer)wildfly
wildfly-build:
	docker build  -t $(wildfly) wildfly

wildfly-run=docker run -d -v $(sparkJobsDir):/sparkJobs  --name wildfly -p 8080:8080 -p 9990:9990 -p 9090:9090 --link mysql --link kafka --link elastic  $(wildfly) 

wildfly-run:
	$(wildfly-run)

wildfly-stop:
	docker stop wildfly
	# Elastic Search: {{{1
	# ----------------------------------------------------------------------------

elastic=$(maintainer)elastic

elastic-build:
	docker build -t $(elastic) elastic

elastic-run = docker run -d --name elastic $(elastic) --volumes-from data

elastic-run:
	$(elastic-run)

# Mysql: {{{1
# ----------------------------------------------------------------------------

mysql=$(maintainer)mysql

mysql-build:
	docker build -t $(mysql) mysql

mysql-run= docker run -d --name mysql --volumes-from data  -e MYSQL_ROOT_PASSWORD=mysql $(mysql)
mysql-run:
	$(mysql-run)

# Kafka: {{{1
# ----------------------------------------------------------------------------

kafka=$(maintainer)kafka

kafka-build:
	docker build -t $(kafka) kafka 

kafka-run= docker run -d  --volumes-from data --name kafka --env ADVERTISED_PORT=9092 --env ADVERTISED_HOST=kafka $(kafka) supervisord -n 
kafka-run:
	$(kafka-run)

kafka-client-run= docker run --rm --link kafka -it  $(client) bash

kafka-server-run= docker run --name kafka --rm -it  $(client)
kafka-server-run:
	$(kafka-server-run)

kafka-client-run:
	$(kafka-client-run)

# Spark: {{{1 (not used at the moment)
# ----------------------------------------------------------------------------
spark-run=docker run -d -v $(sparkJobsDir):/sparkJobs -it  --link mysql --link kafka --link elastic $(wildfly) bash
spark-run:
	$(spark-run)

# Jenkins: {{{1
# ----------------------------------------------------------------------------
jenkins=$(maintainer)jenkins
jenkins-build:
	docker build  -t $(jenkins) jenkins

jenkins-run= docker run -d -e VIRTUAL_PORT=8080 -e VIRTUAL_HOST=jenkins.willie.iwi.uni-sb.de --link wildfly  -it --volumes-from data --name  jenkins $(jenkins)

jenkins-run:
	$(jenkins-run)


# Jira: {{{1
# ----------------------------------------------------------------------------
jira=$(maintainer)jira
jira-build:
	docker build  -t $(jira) jira

jira-run= docker run -d  --volumes-from data -e VIRTUAL_HOST=jira.willie.iwi.uni-sb.de --link postgresql --name jira $(jira)

jira-run:
	$(jira-run)

# Confluence: {{{1
# ----------------------------------------------------------------------------
confluence=$(maintainer)confluence
confluence-build:
	docker build  -t $(confluence) confluence

confluence-run= docker run  -d --rm --volumes-from data  -e VIRTUAL_HOST=confluence.willie.iwi.uni-sb.de --link postgresql --name confluence $(confluence)

confluence-run:
	$(confluence-run)

# Postgresql: {{{1
# ----------------------------------------------------------------------------
postgresql=$(maintainer)postgresql
postgresql-build:
	docker build  -t $(postgresql) postgresql

postgresql-run= docker run -d --name postgresql --volumes-from data $(postgresql)

postgresql-run:
	$(postgresql-run)


# Nginxproxy: {{{1
# ----------------------------------------------------------------------------
nginxproxy=$(maintainer)nginxproxy
nginxproxy-build:
	docker build  -t $(nginxproxy) nginxproxy

nginxproxy-run= docker run  -d  --publish 80:80   -v /var/run/docker.sock:/tmp/docker.sock:ro --name nginxproxy $(nginxproxy)

nginxproxy-run:
	$(nginxproxy-run)
	# Phpmyadmin: {{{1 Todo: create Dockerfile
	# ----------------------------------------------------------------------------
	phpmyadmin=$(maintainer)phpmyadmin
phpmyadmin-build:
	docker build  -t $(phpmyadmin) phpmyadmin

phpmyadmin-run= docker run  -d  --rm  -e VIRTUAL_HOST=phpmyadmin.willie.iwi.uni-sb.de -e MYSQL_USERNAME=root --link mysql --name phpmyadmin $(phpmyadmin)

phpmyadmin-run:
	$(phpmyadmin-run)
	# Sonaqube: {{{1 Todo: create Dockerfile
	# ----------------------------------------------------------------------------
	sonaqube=$(maintainer)sonaqube
sonaqube-build:
	docker build  -t $(sonaqube) sonaqube

sonaqube-run= docker run -d  --rm  -e VIRTUAL_HOST=sonaqube.willie.iwi.uni-sb.de -e VIRTUAL_PORT=9000 --name sonarqube  sonarqube:5.1

sonaqube-run:
	$(sonaqube-run)

# }}}

# vim: set shiftwidth=2 tabstop=2 foldmethod=marker : 
