# Ansible project to manage Jenkins

[jenkins URL](https://ci.marketplace.team/)

We use Jenkins job builder for managing jobs. The best documentation for this is [here](https://jenkins-job-builder.readthedocs.org/en/latest/index.html)

## To setup

 * The DM_CREDENTIALS_REPO environment variable needs to be set to your credentials repo path. (E.g. put it in your bash profile)

## To deploy

To deploy changes, you must define the tags for which you wish to deploy e.g. Run tasks tagged as `jobs`
```bash
$ make jenkins TAGS=jobs
```

Available tags are defined in `/playbooks/roles/jenkins/tasks/main.yml`.

To only update a specific Jenkins job
```bash
$ make jenkins TAGS=jobs JOBS=index_services
```

## To SSH onto the jenkins box

You need a private key file, a username, and the hostname.

```bash
ssh -i [path/to/identity/file] {username}@{hostname}

# eg
ssh -i ../digitalmarketplace-credentials/aws-keys/ci.pem ubuntu@ci.marketplace.team
```

## Running scripts with Python3 via a Jenkins job

To run a script with Python3 inside a Docker container, call the script as follows:

```bash
docker run digitalmarketplace/scripts scripts/my-amazing-script.py arg1 arg2 ...
```

This removes the need for activating a virtualenv or installing requirements with pip.

[More information on running scripts with Docker](https://github.com/alphagov/digitalmarketplace-scripts#running-scripts-with-docker)


## Plugins

The list of plugins in `/playbooks/roles/jenkins/defaults/main.yml` should reflect the list at https://ci.marketplace.team/pluginManager/installed (dependencies
are greyed out on the dashboard, and are not included in the `main.yml` list).

To upgrade a plugin (for example, to address a security vulnerability), tick the relevant box on the Updates panel of the plugins dashboard, and
 click `Download now and install after restart` and follow the instructions given.

 Jenkins should restart during a quiet period when no jobs are running (the restart will take a few seconds).
