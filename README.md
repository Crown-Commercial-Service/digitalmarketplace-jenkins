# Ansible project to manage Jenkins

[jenkins URL](https://ci.marketplace.team/)

We use Jenkins job builder for managing jobs. The best documentation for this is [here](https://jenkins-job-builder.readthedocs.org/en/latest/index.html)

## Infrastructure

The infrastructure that Jenkins runs on is now managed via our Terraform code which is in the digitalmarketplace-aws
repo [here](https://github.com/alphagov/digitalmarketplace-aws/tree/master/terraform/modules/jenkins). Jenkins runs
behind an ELB. The ELB has a certificate provided by Amazon Certificate Manager, and terminates our TLS, before proxying
requests on to the Jenkins instance. The certificate is a wildcard certificate to make it easy to move Jenkins to a
new subdomain if required.

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

Usually, the jenkins jobs you push onto the server will be enabled. However if you're setting up a new box, you will
want to disable them, which can be done as follows:
```bash
make jenkins TAGS=jobs JOBS_DISABLED=true
```

They will also be disabled if you are bootstrapping the box from scratch (i.e. if the `bootstrap`
tag is used, or if no tags are specified).

## To SSH onto the jenkins box

You need a private key file, a username (always 'ubuntu'), and the hostname.

```bash
ssh -i [path/to/identity/file] {username}@{hostname}

# eg
ssh -i ../digitalmarketplace-credentials/aws-keys/ci.pem ubuntu@ci.marketplace.team
```

All GitHub-associated SSH keys for trusted users should work, but you may need to run

```bash
make jenkins TAGS=keys
```

to re-gather these keys first if the SSH key you're using has only recently been added to your GitHub account.

## Running scripts with Python3 via a Jenkins job

To run a script with Python3 inside a Docker container, call the script as follows:

```bash
docker run digitalmarketplace/scripts scripts/my-amazing-script.py arg1 arg2 ...
```

This removes the need for activating a venv or installing requirements with pip.

[More information on running scripts with Docker](https://github.com/alphagov/digitalmarketplace-scripts#running-scripts-with-docker)


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

## Backups

In August 2018 our original Jenkins server, which had been running since 2015, was replaced with a new Jenkins server.
The new server is completely managed by Terraform and Ansible. Before being terminated an AMI was created of the old
server which captured it's setup and both it's volumes. That AMI is stored in the main AWS account, and has AMI ID:
"ami-0042214035374c7b2" and AMI Name: "Jenkins - 2015 to August 2018". If needed the old server can be completely
recreated from this image. WARNING! Jobs may start running as soon as the AMI is started as an instance. To prevent any
unintended actions, it may be a good idea to assign the new image a security group with no egress.
