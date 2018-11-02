comma := ,
colon := :
space :=
space +=

define colorecho
	@tput setaf 6
	@echo $1
	@tput sgr0
endef

define capture-output
	script $1 $2 > /dev/null || cat $1
endef

DM_JENKINS_REPO ?= ..
VIRTUALENV_ROOT := $(DM_JENKINS_REPO)/venv
PATH := $(VIRTUALENV_ROOT)/bin:$(PATH)
SHELL = bash

SRCDIR := $(DM_JENKINS_REPO)/job_definitions
TEST_CACHE := .test_cache

ANSIBLE_OUTDIR := $(TEST_CACHE)/job_builder_definitions
JJB_OUTDIR := $(TEST_CACHE)/jenkins_job_definitions

ifdef JOBS
	JOBS_LIST := $(subst $(comma),$(space),$(JOBS))
else
	JOBS_LIST := $(patsubst %.yml,%,$(notdir $(wildcard $(SRCDIR)/*.yml)))
endif

SOURCES := $(foreach JOB,$(JOBS_LIST),$(SRCDIR)/$(JOB).yml)
TARGETS := $(foreach JOB,$(JOBS_LIST),$(JJB_OUTDIR)/$(JOB).xml)

test-job-templates: $(TARGETS)

pre-populate-cache: $(ANSIBLE_OUTDIR)

define process-templates
	ansible-playbook \
		--inventory="localhost," \
		--extra-vars=@$(DM_JENKINS_REPO)/playbooks/roles/jenkins/defaults/main.yml \
		--extra-vars=@$(DM_JENKINS_REPO)/tests/fixtures/vars.yml \
		--extra-vars="dest=$1" \
		--extra-vars="items=[$(subst $(space),$(comma),$2)]" \
		$(DM_JENKINS_REPO)/tests/test_templates.yml
endef

define process-templates-quiet
	$(call capture-output,$(@:.yml=).log,$(call process-templates,$1,$2))
endef

$(ANSIBLE_OUTDIR):
	@mkdir -p $@
	@$(call colorecho,'Detected first run; generating cache...')
	@$(call process-templates,$@,$(SOURCES))
	@$(eval ALREADY_RAN := true)

$(ANSIBLE_OUTDIR)/%.yml: $(SRCDIR)/%.yml | $(ANSIBLE_OUTDIR)
	@$(call colorecho,'Parsing `$(<F)` with ansible...')
	@$(if $(ALREADY_RAN),,$(call process-templates-quiet,$(@D),$?))

$(JJB_OUTDIR)/%.xml: $(ANSIBLE_OUTDIR)/%.yml
	@mkdir -p $(@D)
	@$(call colorecho,'Parsing `$(<F)` with jenkins-jobs...')
	@tput setaf 1 # print jenkins-jobs warnings in red
	@jenkins-jobs -l=WARNING test $< > $@
	@tput sgr0

generate-fixtures:
	cat ${DM_CREDENTIALS_REPO}/jenkins-vars/jenkins.yaml \
		| sed -n '/sops:/!p;//q' \
		| sed 's/:.*$$/:/' \
		| python fixtures/_gen_stubs.py \
	> fixtures/vars.yml

print-jobs:
	@echo $(TARGETS)
