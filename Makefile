.DEFAULT_GOAL := help
SHELL := /bin/bash
export VIRTUALENV_ROOT := $(shell [ -z ${VIRTUAL_ENV} ] && echo $$(pwd)/venv || echo ${VIRTUAL_ENV})

export ANSIBLE_ROLES_PATH := ${VIRTUALENV_ROOT}/etc/ansible/roles
export ANSIBLE_CONFIG := playbooks/ansible.cfg

# extra variables that, if specified, will override those in playbooks/roles/jenkins/defaults/main.yml
ifdef JOBS_DISABLED
	EXTRA_VARS += -e 'jobs_disabled=${JOBS_DISABLED}'
endif
ifdef JOBS
	EXTRA_VARS += -e 'jobs=${JOBS}'
endif

.PHONY: help
help: ## List available commands
	@cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: venv
venv: ${VIRTUALENV_ROOT}/activate ## Create virtualenv if it does not exist

${VIRTUALENV_ROOT}/activate:
	[ -z $$VIRTUAL_ENV ] && [ ! -d venv ] && python3 -m venv venv || true

.PHONY: requirements
requirements: venv ## Install requirements
	${VIRTUALENV_ROOT}/bin/pip install -Ur requirements.txt
	${VIRTUALENV_ROOT}/bin/ansible-galaxy install -r playbooks/requirements.yml

.PHONY: requirements-test
requirements-test: requirements-dev ## Alias for backwards-compatibility

.PHONY: requirements-dev
requirements-dev: requirements ## Install test requirements
	${VIRTUALENV_ROOT}/bin/pip install -Ur requirements-jenkins-job-builder.txt

.PHONY: clean
clean: ## Clean workspace (delete all generated files)
	rm -rf venv requirements.txt.md5

.PHONY: jenkins
jenkins: requirements ## Run Jenkins playbook specified by TAGS
	$(if ${TAGS},,$(error Must specify a list of ansible tags in TAGS))
	./deploy-jenkins.sh

.PHONY: install
install: requirements ## Completely (re)install Jenkins
	TAGS=all ./deploy-jenkins.sh

.PHONY: keys
keys: requirements ## Update all the keys used and accepted by Jenkins
	TAGS=keys ./deploy-jenkins.sh

.PHONY: jobs
jobs: requirements ## Update all Jenkins jobs
	TAGS=jobs ./deploy-jenkins.sh

# Includes 'jobs' - otherwise views disappear
.PHONY: reconfigure
reconfigure: requirements ## Update the Jenkins configuration and jobs
	TAGS="config,jobs" ./deploy-jenkins.sh

.PHONY: upgrade
upgrade: requirements ## Upgrade Jenkins
	TAGS=jenkins ./deploy-jenkins.sh
