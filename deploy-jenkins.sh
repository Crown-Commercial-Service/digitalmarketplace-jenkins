#!/usr/bin/bash
set -eou pipefail
# Script to run ansible tasks. Use the Makefile instead of running this directly.

${DM_CREDENTIALS_REPO}/sops-wrapper -v > /dev/null

JENKINS_VARS_FILE=$(mktemp)
PRIVATE_KEY_FILE=$(mktemp)
trap 'rm $JENKINS_VARS_FILE $PRIVATE_KEY_FILE' EXIT

for varfile in ${DM_CREDENTIALS_REPO}/jenkins-vars/*.yaml
do
  ${DM_CREDENTIALS_REPO}/sops-wrapper -d $varfile >> $JENKINS_VARS_FILE
done
${DM_CREDENTIALS_REPO}/sops-wrapper -d ${DM_CREDENTIALS_REPO}/aws-keys/ci.pem.enc > $PRIVATE_KEY_FILE

${VIRTUALENV_ROOT}/bin/ansible-playbook \
  -i playbooks/hosts playbooks/jenkins_playbook.yml \
  -e @$JENKINS_VARS_FILE \
  -e "jenkins_public_key='$(ssh-keygen -y -f $PRIVATE_KEY_FILE)'" \
  --key-file=$PRIVATE_KEY_FILE \
  -e "dm_credentials_repo=${DM_CREDENTIALS_REPO}" \
  --tags "${TAGS}" ${EXTRA_VARS:-}
