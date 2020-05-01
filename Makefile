#!/usr/bin/make -f

SHELL := /bin/bash

deb:
	mkdir -p dist
	docker run -ti -e RUN_UID=`id -u` -v `pwd`:/home/bob/build phlax/debian-build bash -c "\
	  cd build \
	  && debuild -b \
	  && cp -a ../*deb dist"

testsecrets:
	if [ -z "$$(gpg --list-keys docker@c.loud)" ]; then \
		echo "key does not exist creating..."; \
		./scripts/generate-test-key; \
	fi
	gpg --export-secret-key -a "Docker Cloud" > ./test.key
	rm -rf /tmp/secret
	rm -rf /tmp/secret-keys*
	mkdir -p /tmp/secret-keys
	mkdir -p /tmp/secret
	echo "VERYSECRET" > /tmp/secret-keys/key1
	echo "ALSOVERYSECRET" > /tmp/secret-keys/key2
	tar cf /tmp/secret-keys.tar -C /tmp/secret-keys/ .
	gpg --output /tmp/secret-keys.tar.gpg --encrypt --recipient docker@c.loud /tmp/secret-keys.tar
	gzip /tmp/secret-keys.tar.gpg
	cp -a /tmp/secret-keys.tar.gpg.gz /tmp/secret

testenv: deb testsecrets
	. test.env \
		&& docker-compose up -d \
		&& $$CLOUD bash -c "\
			apt update \
			&& export DEBIAN_FRONTEND=noninteractive \
			&& apt install -y -qq ca-certificates curl gpg software-properties-common whois \
			&& curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
			&& add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/debian buster stable' \
			&& curl -fsSL https://phlax.github.io/debian/gpg | apt-key add - \
			&& add-apt-repository 'deb [arch=amd64] https://phlax.github.io/debian buster main' \
			&& apt dist-upgrade -y -qq \
			&& apt update" \
		&& $$CLOUD apt install --no-install-recommends --no-install-suggests --reinstall -y -qq "/tmp/dist/docker-cloud_0.0.3_all.deb" \
		&& $$CLOUD bash -c "\
			apt install -y -qq --no-install-recommends python3-pip \
		      	&& pip3 install -U pip setuptools \
			&& pip3 install termcolor \
			&& pip3 install -e 'git+https://github.com/phlax/pysh#egg=pysh.test&subdirectory=pysh.test'"

release:
	export latest=$$(curl https://github.com/repos/phlax/docker-cloud/releases/latest) \
	&& export current=$$(dpkg-parsechangelog --show-field Version) \
	&& echo "Latest release: $$latest" \
	&& echo "Current release: $$current" \
	&& if [ "$$latest" != "$$current" ]; then echo "Releasing $${current}!"; fi
