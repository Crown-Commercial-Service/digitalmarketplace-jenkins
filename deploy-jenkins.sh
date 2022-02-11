#!/usr/bin/env bash
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

EXTRA_VARS=(
  --extra-vars @$JENKINS_VARS_FILE
  --extra-vars "jenkins_public_key='$(ssh-keygen -y -f $PRIVATE_KEY_FILE)'"
  --extra-vars "dm_credentials_repo=${DM_CREDENTIALS_REPO}"
)
if [ ! -z ${JOBS+x} ]
then
  EXTRA_VARS+=(--extra-vars "jobs=${JOBS}")
fi
if [ ! -z ${JOBS_DISABLED+x} ]
then
  EXTRA_VARS+=(--extra-vars "jobs_disabled=${JOBS_DISABLED}")
fi

if [ ! -z ${LOCALHOST+x} ]
then 
  PLAYBOOK="playbooks/jenkins_playbook_local.yml"; 
  EXTRA_VARS+=(--connection "local")
elif [ ! -z ${DMP_SO_CI+x} ]
then
  # Many tags that work for jenkins don't yet work for dmp_so_jenkins. Only allow the tags that are known to be safe.
  if [ "${TAGS}" != "jenkins" -a "${TAGS}" != "apt" -a "${TAGS}" != "keys" ]
  then
    echo "Unsupported tag for dmp-so-ci: ${TAGS}"
    exit 1
  fi

  PLAYBOOK="playbooks/jenkins_playbook_dmp_so.yml"
  EXTRA_VARS+=(--inventory "playbooks/hosts")
else
  PLAYBOOK="playbooks/jenkins_playbook.yml"
  EXTRA_VARS+=(--inventory "playbooks/hosts")
fi

${VIRTUALENV_ROOT}/bin/ansible-playbook \
  $PLAYBOOK \
  --key-file=$PRIVATE_KEY_FILE \
  --tags "${TAGS}" \
  "${EXTRA_VARS[@]}"
