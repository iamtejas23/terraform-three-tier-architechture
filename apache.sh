#!/bin/bash

# Install Docker if it's not already installed
if ! command -v docker &> /dev/null
then
    echo "Docker not found. Installing Docker..."
    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io
    systemctl start docker
    systemctl enable docker
fi

# Pull the Docker image for the React app
echo "Pulling the Docker image for the React app..."
docker pull iamtejas23/e-kart:latest

# Check if a container with the same name is already running and stop it
if [ "$(docker ps -q -f name=e-kart-container)" ]; then
    echo "Stopping and removing the existing container..."
    docker stop e-kart-container
    docker rm e-kart-container
fi

# Run the Docker container
echo "Running the Docker container..."
docker run --name e-kart-container -d -p 8080:80 iamtejas23/e-kart:latest

# Output the status of the container and a success message
if [ "$(docker ps -q -f name=e-kart-container)" ]; then
    echo "Docker container is running. You can access your React app at http://localhost:8080"
else
    echo "Failed to start the Docker container."
fi
