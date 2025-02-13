# Pulling Jenikins Docker image
FROM jenkins/jenkins:lts-jdk17

# Signing-in as root
USER root

# Run commands to update, install, download and add to /usr/share...
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Run update and install packages
RUN apt-get update && apt-get install -y docker-ce-cli

# Set-up Jenkins user
USER jenkins
