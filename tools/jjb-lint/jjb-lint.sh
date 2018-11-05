#!/usr/bin/env bash

usage() {
	echo "Usage: jjb-lint [-h] [-dvx] FILE..."
	echo "Check for basic errors in Jenkins Job Builder .yml files."
	echo "Supports .yml files that are templated using ansible."
	echo ""
	echo "  -h	Display this help message and exit"
	echo "  -d	Do not clean temporary files (useful for debugging)"
	echo "  -v	Verbose mode, use multiple times for more detail"
	echo "  -x	Exit on first issue found"
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
	# Run ansible_lint to generate files
	# suitable for jenkins-jobs, then
	# lint the generated files.

	cd "$OUTDIR"
	mkdir "job_definitions"
	OUTDIR=job_definitions
	catch ansible_lint "${FILES[@]}"
	catch jjb_lint job_definitions/*.yml

	trace -v "finished: $STATUS"

	return "$STATUS"
}

run_ansible()
{
	# Usage: run_ansbile OUTDIR FILES...
	local dest
	local items
	local status

	dest="$(pwd)"/"$1"; shift
	items="$1"; shift
	while (($#))
	do
		items+=","
		items+="$1"
		shift
	done

	try \
	ansible-playbook "$ANSIBLE_VERBOSE" \
		--inventory="localhost," \
		--extra-vars=@"${DM_JENKINS_REPO}/playbooks/roles/jenkins/defaults/main.yml" \
		--extra-vars=@"${DM_JENKINS_REPO}/tests/jenkins-vars.yml" \
		--extra-vars="dest=$dest" \
		--extra-vars="items=[$items]" \
		"${LIBDIR}/test_templates.yml"
}

run_jjb()
{
	# Usage: run_jjb OUTDIR FILES...
	echo "$2"
	try \
	jenkins-jobs \
		test \
		-o "$1" \
		"$2" \
		2>&1
}

parse_ansible_output()
{
	# This command is a filter that transforms
	# ansible's output into a more human readable form.
	#
	# It echoes to stdout one line per issue,
	# in the format
	#   filename: error message
	#
	# It returns 1 if any of the ansible jobs failed,
	# 0 otherwise.

	local status
	status=0

	while read -r line
	do
		# if there is a failure ansible emits a line that includes some json
		# we use jq to parse the json and output the information we want in the correct format
		echo "$line" | grep '^failed' | grep -o '{.*}' | jq -r '.item + ": " + .msg' | sed "s|$CWD/||"

		# record if any of the output lines indicates a failure
		if [[ "$line" == failed:* ]]
		then
			status=1
			if [ "$FAILFAST" = "y" ]
			then
				exit 1
			fi
		fi
	done

	return $status
}

parse_jjb_output()
{
	# This command is a filter that transforms
	# the output of jenkins-jobs messages.
	#
	# It echoes to stdout one line per issue,
	# in the format
	#   filename: error message
	#
	# It returns 1 if jenkins-jobs emitted any
	# warnings or errors, 0 otherwise.

	local status
	status=0

	# the first line from run_jjb will be the filename
	local filename
	read -r filename
	filename=${filename##$CWD/}

	while read -r line
	do
		# Print the warning line with reduced detail
		# (remove the python logging prefixes)
		echo "$filename: $line" | sed -n 's|WARNING:[^ ]*:||p'

		# record if any of the output lines indicates a failure
		if [[ "$line" == WARNING:* ]]
		then
			status=1
			if [ "$FAILFAST" = "y" ]
			then
				exit 1
			fi
		fi
	done

	return $status
}

ansible_lint()
{
	# Usage: ansible_lint FILES...
	# It saves any output files to $OUTDIR
	# It logs to ansible.log
	# Exit status is 1 if any files have issues

	local status

	run_ansible "$OUTDIR" "$@" | pipetrace -a "ansible.log" | parse_ansible_output
	return $?
}

jjb_lint()
{
	# Usage: jjb_lint FILES...
	# It saves any output files to $OUTDIR
	# It logs to jenkins-jobs.log
	# Exit status is 1 if any files have issues
	local status
	status=0

	for f
	do
		# Use uniq before parsing the output because
		# jenkins-jobs will emit an error for each
		# job it finds in a YAML file; our yaml files
		# often the same job repeated for different
		# environments, so we filter out repeated lines
		# to avoid noisy output

		run_jjb "$OUTDIR" "$f" | pipetrace -a "jenkins-jobs.log" | uniq | parse_jjb_output

		status=$((status|$?))
		if [ "$FAILFAST" = "y" ] && [ $status -ne 0 ]
		then
			exit 1
		fi
	done
	return $status
}

###################
## Helper functions
###################

pipetrace()
{
	# A version of tee that prints
	# to screen if $VERBOSE is set
	if [[ "$VERBOSE" == -v* ]]
	then
		tee "$@" /dev/tty
	else
		tee "$@"
	fi
}

trace()
{
	# echo to screen if verbose
	local level
	level=

	if [ $# -gt 1 ]
	then
		level="$1"; shift
	fi

	if [[ "$VERBOSE" == "$level"* ]]
	then
		(>/dev/tty echo "$*")
	fi
}

try()
{
	# issue an error message if command returns non-zero status
	# and exit immediately with FATAL status code
	local status
	status=0

	trace -vv "$*"

	# call the command, must be unqoted
	# shellcheck disable=SC2068
	$@
	status=$?
	trace -vv "$1 exited with status code $status"
	if [ $status -ne 0 ]
	then
		if [ -z "$VERBOSE" ]
		then
			# echo a helpful message to stderr
			trace "$1 exited with status code $status, this may be due to an error, use -v to show more detail"
		fi
		exit "$FATAL"
	fi

	return 0
}

catch()
{
	# update STATUS
	local status
	status=0

	"$@"
	status=$?
	trace -vv "$1 exited with status code $status"
	STATUS=$((STATUS|status))
	return 0
}

#######################################################
## Env
## Setup global vars and the environment for the script
#######################################################

set -Eeuo pipefail

# Treat exit status 127 as fatal
FATAL=127
trap '[ "$?" -ne 127 ] || exit 127' ERR

CWD="$( pwd )"
DM_JENKINS_REPO="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." >/dev/null && pwd )"
LIBDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/lib" >/dev/null && pwd )"
OUTDIR=$(mktemp -d /tmp/jjb-lint.XXX)

CLEAN=y
FAILFAST=n
STATUS=0
VERBOSE=

ANSIBLE_VERBOSE=  # setting this is useful if you have errors with ansible

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
	echo "Temporary files will be saved to $OUTDIR..."
fi

# super verbose
if [[ "$VERBOSE" = -vvvv* ]]
then
	set -x
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
