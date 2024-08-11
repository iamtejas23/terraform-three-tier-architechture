#! /bin/bash
yum install httpd git -y
systemctl start httpd
systemctl status httpd
cd /var/www/html
git clone https://github.com/iamtejas23/jenkins-java-project.git
mv jenkins-java-project/* .