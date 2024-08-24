#!/bin/bash
# Switch to root user
sudo su -

# Update the system and install necessary packages
yum update -y
yum install -y git docker

# Start Docker service
service docker start
chkconfig docker on

# Clone the React app repository from GitHub
git clone https://github.com/iamtejas23/personal-portfolio.git /root/app

# Navigate to the app directory
cd /root/app

# Build and run the Docker container
docker build -t react-app .
docker run -d -p 80:3000 react-app

# Optional: Clean up the Docker images to save space
docker image prune -f
