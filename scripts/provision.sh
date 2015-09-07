#!/bin/sh

export ANSIBLE_CONFIG=playbooks/ansible.cfg
export CREDENTIALS_PATH=$PWD/$1
shift

ansible-playbook -i playbooks/hosts playbooks/jenkins_playbook.yml --private-key ${CREDENTIALS_PATH}/aws-keys/development.pem \
    -e "@${CREDENTIALS_PATH}/jenkins-vars/jenkins.yml" $@
