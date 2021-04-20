#!/usr/bin/env bash

set -o errexit

JOBS=()

JOBS+=('apps-are-up-*')
JOBS+=('apps-are-working-*')
JOBS+=('backup-*')
JOBS+=('build-image')
JOBS+=('clean-and-apply-db-dump-*')
JOBS+=('data-retention-*')
JOBS+=('docker-*')
JOBS+=('database-backup')
JOBS+=('database-migration-paas')
JOBS+=('functional-tests-*')
JOBS+=('index-briefs-*')
JOBS+=('index-services-*')
JOBS+=('notify-buyers*')
JOBS+=('notify-suppliers*')
JOBS+=('release-*')
JOBS+=('rotate-api-tokens')
JOBS+=('rotate-production-notify-callback-token')
JOBS+=('tag-application-deployment')
JOBS+=('validate-cloudtrail-*')
JOBS+=('visual-regression-*')
JOBS+=('update-*-index-alias')

for d in "${JOBS[@]}"; do
    rsync -vazh -e "ssh -i ~/.ssh/<private key to use>" --progress --include 'builds**' --include 'last*' --include 'nextBuildNumber' --exclude '*' jenkins@<source instance host>:/data/jenkins/jobs/"$d" /data/jenkins/jobs/"$d"
done
