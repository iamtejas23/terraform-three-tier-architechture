#!/bin/bash
amazon-linux-extras install -y docker
service docker start
usermod -a -G docker ec2-user
docker run -d -p 80:80 iamtejas23/e-kart:latest
