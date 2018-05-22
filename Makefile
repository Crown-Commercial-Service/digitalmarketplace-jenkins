.DEFAULT_GOAL := help
SHELL := /bin/bash
VIRTUALENV_ROOT := $(shell [ -z ${VIRTUAL_ENV} ] && echo $$(pwd)/venv || echo ${VIRTUAL_ENV})

JOBS ?= '*'

.PHONY: help
help: ## List available commands
	@cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: requirements
requirements: venv ## Install requirements
	${VIRTUALENV_ROOT}/bin/pip install -Ur requirements.txt

.PHONY: venv
venv: ${VIRTUALENV_ROOT}/activate ## Create virtualenv if it does not exist

${VIRTUALENV_ROOT}/activate:
	[ -z $$VIRTUAL_ENV ] && [ ! -d venv ] && virtualenv -p python3 venv || true

.PHONY: clean
clean: ## Clean workspace (delete all generated files)
	rm -rf venv requirements.txt.md5

.PHONY: jenkins
jenkins: venv ## Run Jenkins playbook
	$(if ${TAGS},,$(error Must specify a list of ansible tags in TAGS))
	@set -e ;\
	${DM_CREDENTIALS_REPO}/sops-wrapper -v > /dev/null ;\
	JENKINS_VARS_FILE=$$(mktemp) ;\
	PRIVATE_KEY_FILE=$$(mktemp) ;\
	trap 'rm $$JENKINS_VARS_FILE $$PRIVATE_KEY_FILE' EXIT ;\
	${DM_CREDENTIALS_REPO}/sops-wrapper -d ${DM_CREDENTIALS_REPO}/jenkins-vars/jenkins.yaml > $$JENKINS_VARS_FILE ;\
	${DM_CREDENTIALS_REPO}/sops-wrapper -d ${DM_CREDENTIALS_REPO}/aws-keys/ci2.pem.enc > $$PRIVATE_KEY_FILE ;\
	ANSIBLE_CONFIG=playbooks/ansible.cfg ${VIRTUALENV_ROOT}/bin/ansible-playbook \
		-i playbooks/hosts playbooks/jenkins_playbook.yml \
		-e @$$JENKINS_VARS_FILE \
		-e "jenkins_2_public_key='$$(ssh-keygen -y -f $$PRIVATE_KEY_FILE)'" \
		--key-file=$$PRIVATE_KEY_FILE \
		-e "dm_credentials_repo='$$(realpath ${DM_CREDENTIALS_REPO})'" \
		--tags "${TAGS}" -e "jobs=${JOBS}"
