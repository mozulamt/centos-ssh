FROM centos:7.9.2009

ARG RELEASE_VERSION=2.6.3

# ------------------------------------------------------------------------------
# - Import the RPM GPG keys for repositories
# - Base install of required packages
# - Install supervisord (used to run more than a single process)
# - Install supervisor-stdout to allow output of services started by
#  supervisord to be easily inspected with "docker logs".
# ------------------------------------------------------------------------------
RUN rpm --rebuilddb \
	&& rpm --import \
		http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
	&& rpm --import \
		https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 \
	&& rpm --import \
		https://repo.ius.io/RPM-GPG-KEY-IUS-7 \
	&& yum -y install \
			--setopt=tsflags=nodocs \
			--disableplugin=fastestmirror \
		centos-release-scl \
		epel-release \
		https://repo.ius.io/ius-release-el7.rpm \
	&& yum -y install \
			--setopt=tsflags=nodocs \
			--disableplugin=fastestmirror \
		inotify-tools-3.14-9.el7 \
		openssh-clients-7.4p1-21.el7 \
		openssh-server-7.4p1-21.el7 \
		openssl-1.0.2k-19.el7 \
		python-setuptools-0.9.8-7.el7 \
		python-pip \
		iproute \
		sudo-1.8.23-10.el7_9.2 \
		yum-plugin-versionlock-1.1.31-54.el7_8 \
	&& yum versionlock add \
		inotify-tools \
		openssh \
		openssh-server \
		openssh-clients \
		python-setuptools \
		sudo \
		yum-plugin-versionlock \
	&& yum clean all \
	&& pip install \
		'supervisor==4.0.4' \
		'supervisor-stdout==0.1.1' \
	&& mkdir -p \
		/var/log/supervisor/ \
	&& rm -rf /etc/ld.so.cache \
	&& rm -rf /sbin/sln \
	&& rm -rf /usr/{{lib,share}/locale,share/{man,doc,info,cracklib,i18n},{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive} \
	&& rm -rf /{root,tmp,var/cache/{ldconfig,yum}}/* \
	&& > /etc/sysconfig/i18n

# ------------------------------------------------------------------------------
# Copy files into place
# ------------------------------------------------------------------------------
ADD src /

# ------------------------------------------------------------------------------
# Provisioning
# - UTC Timezone
# - Networking
# - Configure SSH defaults for non-root public key authentication
# - Enable the wheel sudoers group
# - Replace placeholders with values in systemd service unit template
# - Set permissions
# ------------------------------------------------------------------------------
RUN ln -sf \
		/usr/share/zoneinfo/UTC \
		/etc/localtime \
	&& echo "NETWORKING=yes" \
		> /etc/sysconfig/network \
	&& sed -i \
		-e 's~^PasswordAuthentication yes~PasswordAuthentication no~g' \
		-e 's~^#PermitRootLogin yes~PermitRootLogin no~g' \
		-e 's~^#UseDNS yes~UseDNS no~g' \
		-e 's~^\(.*\)/usr/libexec/openssh/sftp-server$~\1internal-sftp~g' \
		/etc/ssh/sshd_config \
	&& sed -i \
		-e 's~^# %wheel\tALL=(ALL)\tALL~%wheel\tALL=(ALL) ALL~g' \
		-e 's~^# %wheel[[:space:]]*ALL=(ALL)[[:space:]]*NOPASSWD: ALL~%wheel ALL=(ALL) NOPASSWD: ALL~g' \
		-e 's~\(.*\) requiretty$~#\1requiretty~' \
		/etc/sudoers \
	&& sed -i \
		-e "s~{{RELEASE_VERSION}}~${RELEASE_VERSION}~g" \
		/etc/systemd/system/centos-ssh@.service \
	&& chmod 644 \
		/etc/{supervisord.conf,supervisord.d/{20-sshd-bootstrap,50-sshd-wrapper}.conf} \
	&& chmod 700 \
		/usr/{bin/healthcheck,sbin/{scmi,sshd-{bootstrap,wrapper},system-{timezone,timezone-wrapper}}}

EXPOSE 22

# ------------------------------------------------------------------------------
# Set default environment variables
# ------------------------------------------------------------------------------
ENV \
	ENABLE_SSHD_BOOTSTRAP="true" \
	ENABLE_SSHD_WRAPPER="true" \
	ENABLE_SUPERVISOR_STDOUT="true" \
	SSH_AUTHORIZED_KEYS="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEApvHBNbVaKzNk8gZniCDZ6PoW88gQpk3k5MkICmIt5F5w7hVG5yWuWRWK/x4+usUdCJRkV6EtfDzRY7Vnz6H0E6WrI4v+dCxpob4pgaXX79gv8Q6gM0jlu/efY9NmRXd1OBRpGSqwfM9f1p+vxla1Mh8U2bLC68ZVy69/Vn0dYc2yHrkQ3e7nFR0ng6qfPT4NDYfRY9fgdViivBXpfV1F/QVshG5pj1btS2GErt/KjfW/kJbpnTW5dwEiHjsZMQ8AzTqJ1bXaQimmN3BWOainDkRqW2ePp04Hk2p6w5lhzKUqH+23V42NlFw4IaEJU/9uqMn9/wP82kl5rguelV7UXw==" \
	SSH_CHROOT_DIRECTORY="%h" \
	SSH_INHERIT_ENVIRONMENT="false" \
	SSH_PASSWORD_AUTHENTICATION="false" \
	SSH_SUDO="ALL=(ALL) ALL" \
	SSH_USER="codeexec" \
	SSH_USER_FORCE_SFTP="false" \
	SSH_USER_HOME="/home/%u" \
	SSH_USER_ID="1000:1000" \
	SSH_USER_PASSWORD="ch00p4d00p4" \
	SSH_USER_PASSWORD_HASHED="false" \
	SSH_USER_PRIVATE_KEY="" \
	SSH_USER_SHELL="/bin/bash" \
	SYSTEM_TIMEZONE="UTC"

# ------------------------------------------------------------------------------
# Set image metadata
# ------------------------------------------------------------------------------
LABEL \
	maintainer="Niels Maumenee <nmaumenee@vultr.com>" \
	install="docker run \
--rm \
--privileged \
--volume /:/media/root \
mozulamt/centos-ssh:${RELEASE_VERSION} \
/usr/sbin/scmi install \
--chroot=/media/root \
--name=\${NAME} \
--tag=${RELEASE_VERSION} \
--setopt='--volume {{NAME}}.config-ssh:/etc/ssh'" \
	uninstall="docker run \
--rm \
--privileged \
--volume /:/media/root \
mozulamt/centos-ssh:${RELEASE_VERSION} \
/usr/sbin/scmi uninstall \
--chroot=/media/root \
--name=\${NAME} \
--tag=${RELEASE_VERSION} \
--setopt='--volume {{NAME}}.config-ssh:/etc/ssh'" \
	org.deathe.name="centos-ssh" \
	org.deathe.version="${RELEASE_VERSION}" \
	org.deathe.release="mozulamt/centos-ssh:${RELEASE_VERSION}" \
	org.deathe.license="MIT" \
	org.deathe.vendor="mozulamt" \
	org.deathe.url="https://github.com/mozulamt/centos-ssh" \
	org.deathe.description="OpenSSH 7.4 / Supervisor 4.0 / EPEL/IUS/SCL Repositories - CentOS-7 7.9.2009 x86_64."

HEALTHCHECK \
	--interval=1s \
	--timeout=1s \
	--retries=5 \
	CMD ["/usr/bin/healthcheck"]

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
