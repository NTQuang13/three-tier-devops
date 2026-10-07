#!/bin/bash
set -e
dnf update -y
dnf install -y git docker java-17-amazon-corretto ansible-core

wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins

ansible-galaxy collection install community.docker -p /usr/share/ansible/collections

systemctl enable --now docker
usermod -aG docker jenkins
systemctl enable --now jenkins