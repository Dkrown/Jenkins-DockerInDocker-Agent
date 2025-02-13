This README.md is mainly for adding agent to Jenkins web UI after running the associated 'docker-compose' file in this doc.

Step 1:
-------
Dockerfile and 'docker-compose.yml' as to be in the same directory.

Step 2:
-------
If using the sample 'Dockerfile and docker-compose.yml' files in doc, try read and understand what the files does, after that run this command 'docker compose up -d'. This will pull the images needed, build and start the services [all three from the 'docker-compose.yml'].

Step 3:
-------
Obtain the 'initial password' for Jenkins web UI using this command 'docker compose logs jenkins-server'. Copy the 'initial password' and go to Jenkins web UI using 'http://localhost:8080' and paste the 'initial password' into the require box and follow the prompt to download require plugins and configure username and new password. After this, you should be seeing the Jenkins web UI 'Dashboard'.

NOTE: If by any chance, you already configured username and password, and wanted to reset back to Jenkins web UI for initial password, run this command 'docker compose down -v'. The flag v [-v], will refresh the 'volumes in the docker-compose.yml'. After that, run 'docker compose up -d' to rebuild/refresh the Jenkins web UI for the 'initial password'.

Step 4:
-------
Generate SSH key pair to use to connect Jenkins with agent. To generate the key pair use these commands:

ssh-keygen -t ed25519 -f ~/.ssh/agent1 -C "Agent1-sshkey"

The above commands will generate a key pair using 'ED25519 encryption keys [private and public]' into the sub-directory [~/.ssh/] with names [agent1 and agent1.pub] and a comment [agent1-sshkey] added to the key pair generated.

Step 5:
------
cat the private key using this command 'cat ~/.ssh/agent1', copy it and go to Jenkins web UI Dashboard -> Manage Jenkins -> Credentials -> (global) -> Add credentials. Then fill in the form as follows:

Scope:		Global(Jenkins, nodes, items, all child items, etc)
ID:		jenkins [all lowercase]
Description:	Jenkins agent1 ssh-key [use whatever description]
username:	jenkins [all lowercase]
Private key:	click on the 'radio [round]' button for 'Enter directly'
		and press the add button to insert/paste the ssh key.
		Finally, click save.

Step 6:
-------
From the terminal, from the following commands to extract and copy the agent [agent1] ssh public key to inside the agent container:

# 1. Assign the container ID to a variable:
CONTAINER_ID="e15843b46f3a"  # Or use container name: jenkins-agent1-1

# 2. Copy the public key file into the container:
docker cp ~/.ssh/agent1.pub "${CONTAINER_ID}:/tmp/agent1.pub"

# 3. Execute commands inside the container to configure SSH access:
docker exec -it "${CONTAINER_ID}" bash -c \
'mkdir -p /home/jenkins/.ssh && \
 cat /tmp/agent1.pub >> /home/jenkins/.ssh/authorized_keys && \
 chown -R jenkins:jenkins /home/jenkins/.ssh && \
 chmod 700 /home/jenkins/.ssh && \
 chmod 600 /home/jenkins/.ssh/authorized_keys'

# 4. (Optional) Remove the temporary copy of the public key from the container:
docker exec "${CONTAINER_ID}" rm /tmp/agent1.pub

Step 7:
------
Go back to Jenkins web UI Dashboard -> Manage Jenkins -> Nodes -> New Node and fill in the form as follow:

Name:			Jenkins-Agent1 [what use whatever name you like]
Type:			Permanent Agent and click on 'Create'.
Remote root directory:	/home/jenkins/agent
Lables:			Jenkins-Agent1 [also call it whatever you like]
Launch method:		Launch agent via SSH
	-Host:		agent1 [NOTE: This is hostname that Jenkins will use to connect
				to the agent. Since all services are on the same
				network 'jenkins', Docker's internal DNS will resolve this
				to the agent's container IP address on the network.
Credentials:		Select 'Jenkins(...with the populated private SSH key added ealier)
Host Key Verification:	Select 'Manually trusted key Verification Strategy'

All others keep as 'Default' and click 'Save'.

Step 8:
-------
The node [agent1] should be 'online and launched'. If that is not the case, press the 'Relaunch agent' button and wait a few seconds. While waiting, click on 'Log' ob the left pane, and check the logs for successful connection.

If for any reason your node does't connected with Jenkins, try to re-visit all the steps mentioned above to check if you missed something or in a few cases 'typo!'


NOTES AND EXPLANATIONS:
=======================
When configuring the new node in Jenkins, the crucial information that you need to get right is the connection information, specifically:

Host/IP Address: This is the IP address or hostname that Jenkins will use to connect to the agent. Since you have all services on the same Docker network (jenkins), you can usually use the service name agent1 (or jenkins-agent1-1, the default name) as the hostname. Docker's internal DNS will resolve this to the container's IP address on the network. Alternatively, you can find the IP address of agent1 using docker inspect <container_id> and looking for the IP address assigned to it on the jenkins network.

Port: You've exposed port 22 on the host machine and mapped it to port 22 inside the container. So, you should typically use port 22 in the Jenkins configuration.

Credentials: You need to configure Jenkins to use the correct SSH credentials (the same public key you copied into the container) to connect to the agent. This typically involves configuring Jenkins with the private key that corresponds to the public key you copied into the agent's authorized_keys file.

User Name: Ensure Jenkins uses the correct username that you are setting up access through (in your setup it's the default jenkins).

Example:
Let's say you named your Jenkins node "MyAgent" in the Jenkins web UI. The important settings would be:

Name: MyAgent (This is arbitrary - you can choose any name you want)
Remote root directory: /home/jenkins/agent (or wherever you mounted the volume, if you used one)
Host: agent1 (or jenkins-agent1-1 if you didn't define the alias)
Port: 22
Credentials: Select the credentials you configured with the private key
User: jenkins
-------------


jenkins-docker Healthcheck:
===========================
healthcheck: This section defines the healthcheck configuration.

test: ["CMD-SHELL", "docker info || exit 1"]: This specifies the command to run for the healthcheck. Here, it runs docker info inside the container. If docker info succeeds (meaning the Docker daemon is running), the healthcheck passes. If docker info fails, the healthcheck fails (exits with code 1). The CMD-SHELL format is used to execute the command in a shell. Adjust as required.

interval: 30s: How often to run the healthcheck.
timeout: 10s: How long to wait for the healthcheck to complete before considering it a failure.
retries: 3: How many consecutive failures are allowed before the container is considered unhealthy.
start_period: 60s: How long to wait after the container has started before starting health checks. This is important to give the service time to initialize fully.

jenkins-server Healthcheck:
===========================
test: ["CMD-SHELL", "curl -f http://localhost:8080/login || exit 1"]: This uses curl to check if the Jenkins web interface is accessible. Replace http://localhost:8080/login with the appropriate URL for your Jenkins login page. The -f flag makes curl return an error code if the HTTP request fails.

depends_on: - jenkins-docker: This tells Docker Compose that jenkins-server depends on jenkins-docker. Docker Compose will start jenkins-docker before starting jenkins-server, and it will wait for the jenkins-docker service to be healthy before proceeding with jenkins-server startup.

agent1 Dependency:
==================
depends_on: - jenkins-server: This tells Docker Compose that agent1 depends on jenkins-server. It will start jenkins-server before starting agent1 and will wait for jenkins-server to be healthy before proceeding with agent1 startup.

How It Works:
=============
When you run docker-compose up -d, Docker Compose will start the containers in the following order:

1.	jenkins-docker
2.	jenkins-server
3.	agent1

Docker Compose will wait for the jenkins-docker container to become healthy (healthcheck passes) before starting jenkins-server.

Docker Compose will wait for jenkins-server to become healthy before starting agent1.
-------------------------------------------------------------------------------------

ADDITIONAL COMMANDS
===================
Restart:
--------
docker compose down
docker compose up -d

To get the host IP [docker agent], use either of these commands below:
======================================================================
1. docker inspect jenkins-agent1-1 | grep '"IPAddress":' | awk -F '"' '{print $4}'
2. docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' jenkins-agent1-1

docker inspect jenkins-agent | grep '"22"'
docker exec -it jenkins-agent1-1 bash
ps aux | grep sshd

Stop docker:
------------
docker stop $(docker ps -q)

Stop and remove all containers:
-------------------------------
docker stop $(docker ps -aq) && docker rm $(docker ps -aq)

Clean sweep docker [images, containers, networks]:
--------------------------------------------------
docker system prune -af [Careful with this command as it removes everything!]

To obtain initial password for Jenkins web UI:
----------------------------------------------
docker exec -it jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword  

ADDITIONAL INFORMATION ON GITHUB:
================================
Creating your github repository:
================================
#Test SSH connection to github from your Linux CLI using this command
ssh -T git@github.com
- If you get the below response back, your ssh connection is ok, otherwise...
- Hi Yourname! You've successfully authenticated, but GitHub does not provide shell access.

#Back to github
#From your github account, click the "+" icon in the top right corner of the page
#then select  "New repository" from the dropdown menu and fill out Repository info.
#Do not initialise README or add any .gitignore or license files on, as these will
#be created locally from your terminal.

#Now, the fun part, go to your terminal and start running these commands
echo "echo "# yourfile" >> README.md (This create READ.md file needed)
git init
git add README.md
git commit -m "Initial commit"(You can change message in double quote, if you want)

#NOTE: After running the last command (git commit -m...) above, you might a message, if you, run the these commands
git config --global user.email "your_email@whatever.com" (email used to open github)
git config --global user.email "your_github_profile_name"

#Now, continue...
git branch -m main
git remote add origin git@github.com:profile_name/repository_name.git
git push -u origin main
NOTE: If you get a complain 'fatal: Authentication failed for 'https://github.com/...' run the below commands instead. The 'warning' is related to 'SSH' authentication [you might have configured between your git account and your host machine].

#OR use these…
git branch -m main
git remote set-url origin git@github.com:profile_name/repository_name.git
git push -u origin main
