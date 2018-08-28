#!/usr/bin/env bash

set -o errexit

for d in {release-*,functional-tests-*,visual-regression-*,build-image,database-migration-paas,tag-application-deloyment,clean-and-apply-db-dump-*,index-services-*,index-briefs-*,update-*-index-alias,data-retention-*,database-backup,rotate-api-tokens,rotate-production-notify-callback-token}/; do
    rsync -vazh -e "ssh -i ~/.ssh/<private key to use>" --progress --include 'builds**' --include 'last*' --include 'nextBuildNumber' --exclude '*' jenkins@<source instance host>:/data/jenkins/jobs/"$d" /data/jenkins/jobs/"$d"
done
