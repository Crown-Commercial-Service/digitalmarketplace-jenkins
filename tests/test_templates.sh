#!/usr/bin/env bash

usage() {
	echo "Usage: jjb-lint [-h] [-d] FILE..."
	echo "Check for basic errors in Jenkins Job Builder .yml files."
	echo "Supports .yml files that are templated using ansible."
	echo ""
	echo "  -h	Display this help message and exit"
	echo "  -d	Do not clean temporary files (useful for debugging)"
	echo ""
	echo "Exits with zero if no issues are found, non-zero otherwise."
	echo "Exit status 127 indicates a fatal error occured."
	echo ""
	echo "For details on Jenkins Job Builder go to <https://docs.openstack.org/infra/jenkins-job-builder/>"
}

###############################################
## Main functions
## Define main at the top, called at the bottom
###############################################

main()
{
	local STATUS
	STATUS=0

	cd "$OUTDIR"
	mkdir "job_definitions"

	copy_ansible_playbook "test_templates.yml"
	copy_jenkins_vars "jenkins-vars.yml"

	colorecho "Generating YAML files for Jenkins Job Builder with Ansible..."
	run_ansible "job_definitions" "${FILES[@]}"
	STATUS=$((STATUS|$?))
	colorecho "done"

	colorecho "Generating INI config file for Jenkins Job Builder..."
	copy_jjb_config "jenkins_jobs.ini"
	colorecho "done"

	run_jjb "job_definitions" "job_definitions"

	colorecho "$0 finished with status code $STATUS"
	exit $STATUS
}

run_ansible()
{
	# Usage: run_ansbile OUTDIR FILES...
	local dest
	local items
	local status

	status=0

	dest="$(pwd)"/"$1"; shift
	items="$1"; shift
	while (($#))
	do
		items+=","
		items+="$1"
		shift
	done

	ansible-playbook \
		--inventory="localhost," \
		--extra-vars=@"${DM_JENKINS_REPO}/playbooks/roles/jenkins/defaults/main.yml" \
		--extra-vars=@"jenkins-vars.yml" \
		--extra-vars="dest=$dest" \
		--extra-vars="items=[$items]" \
		"test_templates.yml"

	status=$?
	if [ $status -ne 0 ] && [ $status -ne 2 ]
	then
		colorecho "ansible-playbook returned error code $status, cannot continue"
		exit 127
	elif [ $status -eq 2 ]
	then
		return 1
	fi

	return $status
}

run_jjb()
{
	# Usage: run_jjb OUTDIR FILES...
	jenkins-jobs \
		--conf "jenkins_jobs.ini" \
		test \
		--config-xml \
		-o "$1" \
		"$2" \
		2>&1
}

copy_ansible_playbook()
{
	cat <<- EOF > "$1"
		- hosts: localhost
		  connection: local
		  gather_facts: no
		  tasks:
		  - name: Process templates
		    template: src={{ item }} dest={{ dest }}
		    loop: "{{ items | from_yaml }}"
		EOF
}

copy_jenkins_vars()
{
	cp "$DM_JENKINS_REPO/tests/$1" .
}

copy_jjb_config()
{
	# We want to test jenkins-jobs with the
	# configuration used in production, but
	# we want to tweak it slightly to avoid
	# jenkins-jobs contacting jenkins

	run_ansible "$1" "${DM_JENKINS_REPO}/playbooks/roles/jenkins/templates/jenkins_jobs.ini.j2"

	# If jenkins-jobs finds a configuration file
	# it tries to contact the Jenkins server
	# to detect what plugins are installed,
	# unless `query_plugins_info` is set to False
	# in the configuration file.
	# See <https://docs.openstack.org/infra/jenkins-job-builder/execution.html#jenkins-section>
	sed \
		-i '.orig' \
		-e '/\[jenkins\]/a\
query_plugins_info=False' \
		"$1"
}

colorecho()
{
	tput setaf 6
	echo "$@"
	tput sgr0
}

#######################################################
## Env
## Setup global vars and the environment for the script
#######################################################

set -Eeuo pipefail

CWD="$( pwd )"
OUTDIR=$(mktemp -d /tmp/jjb-test.XXX)

DM_JENKINS_REPO="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null && pwd )"

CLEAN=y
STATUS=0
VERBOSE=

#############################
## Parse command line options
#############################

while getopts "dhvx" opt
do
	case $opt in
		d)
			CLEAN=n
			;;
		v)
			if [ -z "$VERBOSE" ]
			then
				VERBOSE+=-
			fi
			VERBOSE+=v
			;;
		x)
			FAILFAST=y
			;;
		h|\?)
			usage
			exit 2
			;;
	esac
done

shift $((OPTIND-1))

if [ "$CLEAN" = "y" ]
then
	# clean up afterwards
	# we use double quotes because
	# OUTDIR changes later
	# shellcheck disable=SC2064
	trap "rm -r $OUTDIR" EXIT
else
	trap "echo Output files saved to $OUTDIR..." EXIT
fi

# get absolute file paths for FILE...
# and save into array FILES
declare -a FILES
for f
do
	FILES+=("$CWD"/"$f")
done

# exit script if user hits Ctrl-C
trap exit SIGINT

# unfortunately having set -e catching errors
# interferes with the logic of this script
set +e

#############
## Entrypoint
#############

main
