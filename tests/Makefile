
generate-fixtures:
	cat ${DM_CREDENTIALS_REPO}/jenkins-vars/jenkins.yaml \
		| sed -n '/sops:/!p;//q' \
		| sed 's/:.*$$/:/' \
		| python fixtures/_gen_stubs.py \
	> fixtures/vars.yml
