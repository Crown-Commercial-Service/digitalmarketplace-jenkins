# Digital Marketplace Jenkins

An Ansible project to manage the Digital Marketplace [Jenkins instance](https://ci.marketplace.team/).

We use [Jenkins job builder](https://jenkins-job-builder.readthedocs.org/en/latest/index.html) for managing jobs.

The infrastructure that Jenkins runs on is now managed via our Terraform code, found in the [digitalmarketplace-aws
repo](https://github.com/Crown-Commercial-Service/digitalmarketplace-aws/tree/main/terraform/modules/jenkins).

## Making changes to Jenkins

### Setup

To make changes to Jenkins configuration or jobs, you will need:

 * The `DM_CREDENTIALS_REPO` environment variable to be set to your credentials repo path (e.g. in your bash profile)
 * GDS network or VPN access

### Updating jobs

The Ansible tasks are grouped by tags. See [`playbooks/roles/jenkins/tasks/main.yml`](playbooks/roles/jenkins/tasks/main.yml). Use `make jenkins TAGS=your_tag_here` to run a particular set of tagged tasks.

All job definitions will be updated automaticaly when merged to `main`. This is perfomed by the [`job_definitions/update_jenkins_job_definitions.yml`](job_definitions/update_jenkins_job_definitions.yml) job.

If you need to test a job from a branch or deploy manually you can run the commands below from your local machine:

To update all job definitions (i.e. run the Ansible tasks tagged as `jobs`):
```bash
$ make jobs
```

To only update a specific Jenkins job:
```bash
$ make jobs JOBS=index_services
```

Usually, the Jenkins jobs you push onto the server will be enabled. However if you're setting up a new box, you will
want to disable them, which can be done as follows:
```bash
$ make jobs JOBS_DISABLED=true
```

Jobs will also be disabled if you are bootstrapping the box from scratch (i.e. if the `bootstrap`
tag is used, or if no tags are specified).

### Other commands

Note that these commands involve restarting Jenkins - make sure Jenkins is put into shutdown mode
before running them.

To update Jenkins settings (e.g. adding a job to a tab group in the UI):
```bash
$ make reconfigure
```

To upgrade the Jenkins version:
```bash
$ make upgrade
```

### Troubleshooting

If you encounter Python 3.x/OpenSSL errors when running the Ansible playbooks, try the following from within your Python3 virtualenv:

```bash
$ pip install certifi
$ export SSL_CERT_FILE=venv/lib/python3.8/site-packages/certifi/cacert.pem
```

If you still get a certificate error, try:

```bash
$ open /Applications/Python\ 3.8/Install\ Certificates.command
```

## SSH access to Jenkins

You need a private key file, a username (always 'ubuntu'), and the hostname. You need to be connected to the VPN or corporate network.

```bash
ssh -i [path/to/identity/file] {username}@{hostname}

# eg
ssh -i ../digitalmarketplace-credentials/aws-keys/ci.pem ubuntu@ci.marketplace.team
```

All GitHub-associated SSH keys for trusted users should work. However if the SSH key has only recently
been added to the Github account, you may need to re-gather the keys with:

```bash
make keys
```

## Running scripts with Python3 via a Jenkins job

To run a script with Python3 inside a Docker container, call the script as follows:

```bash
docker run digitalmarketplace/scripts scripts/my-amazing-script.py arg1 arg2 ...
```

This removes the need for activating a virtualenv, or installing requirements with pip on the Jenkins
instance itself.

[More information on running scripts with Docker](https://github.com/Crown-Commercial-Service/digitalmarketplace-scripts#running-scripts-with-docker)


## Plugins

The list of plugins in `/playbooks/roles/jenkins/defaults/main.yml` should reflect the list at https://ci.marketplace.team/pluginManager/installed (dependencies
are greyed out on the dashboard, and are not included in the `main.yml` list).

To upgrade a plugin (for example, to address a security vulnerability), tick the relevant box on the Updates panel of the plugins dashboard, and
 click `Download now and install after restart` and follow the instructions given.

Jenkins should restart during a quiet period when no jobs are running (the restart will take a few seconds).


## Authentication

Authentication is managed via a Github OAuth app owned by the user `dm-ssp-jenkins` on
Github. The password is in `logins.enc` in the credentials repo.

An application exists per Jenkins instance - see *Settings/Developer settings/Oauth Apps* once logged into Github with
the `dm-ssp-jenkins` user. The Client ID and Client Secret must be stored in the credentials repo, in
*jenkins-vars/jenkins.yaml*, and must be stored as a nested dict under `jenkins_github_auth_by_hostname`. This allows
us to maintain multiple Jenkins instances (if required). These credentials are deployed via the `config` task tag.

## Creating a new Jenkins instance

The process for creating a new instance is documented in [the team manual](https://crown-commercial-service.github.io/digitalmarketplace-manual/2nd-line-runbook/rebuilding-jenkins.html).

## Logging

The Jenkins server captures the following logs:

- Events, using the [Jenkins Audit Trail plugin](https://wiki.jenkins.io/display/JENKINS/Audit+Trail+Plugin)
- Access logs (see [PR #171](https://github.com/Crown-Commercial-Service/digitalmarketplace-jenkins/pull/171))
- SSH Access logs (see [PR #172](https://github.com/Crown-Commercial-Service/digitalmarketplace-jenkins/pull/172))

The log files are sent to CloudWatch for long term storage. See PR [PR #173](https://github.com/Crown-Commercial-Service/digitalmarketplace-jenkins/pull/173)
and the `awslogs-config` section in `playbooks/jenkins_playbook.yml` for more details.

## Licence

Unless stated otherwise, the codebase is released under [the MIT License][mit].
This covers both the codebase and any sample code in the documentation.

The documentation is [&copy; Crown copyright][copyright] and available under the terms
of the [Open Government 3.0][ogl] licence.

[mit]: LICENCE
[copyright]: http://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/uk-government-licensing-framework/crown-copyright/
[ogl]: http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/
