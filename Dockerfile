# This image is based on centos, which is the closest distribution to the supported RHEL
FROM centos

# That would be me... they told me to comment the code...
MAINTAINER Yann Bizeul

# We need some additional packages to install and run OCUM
RUN yum install -y epel-release policycoreutils-python java perl-Data-Dumper sudo sendmail redhat-lsb which bind-utils rrdtool; yum clean all

# Make OCUM installer believe we are running on RHEL 7
RUN echo "Red Hat Enterprise Linux Server 7.2.1503" > /etc/redhat-release

# Make OCUM installer believe we have plenty of RAM
# For this, we setup a fake "free" command that returns a statix output
RUN mv /usr/bin/free /usr/bin/free.orig; echo -e "cat << EOF \n\
              total        used        free      shared  buff/cache   available\n\
Mem:            12979         146          10000           6         766         644\n\
Swap:          2047           0        2047\n\
EOF" > /usr/bin/free; chmod 755 /usr/bin/free

# systemctl doesn't play well in docker, but OCUM comes with some services using systemctl by default
# We move it away from now and will replace with another script next line

RUN mv /usr/bin/systemctl /usr/bin/systemctl_

# We need start-stop-daemon binary compiled on another linux OS because we can't
# rely on systemctl and the fallback is to use start-stop-daemon not present on RHEL
# or Centos 7

# Wwe intercept systemctl calls to run the legacy "service" command instead
# systemctl daemon-reload
# systemctl start rp

COPY systemctl start-stop-daemon /usr/bin/

#<- Add a comment "#" sign here, and read what follows
# That's all I found to catch your attention. Be careful here, the following line copies
# a repository file that contains the packages for OCUM. The bad news is : you will have to provide one
# The way files are distributed on a docker build makes it highly inefficient to copy these RPM in the build
# directory, so we download and install them.
# Easiest way to do it is probably to use a http container presenting a yum repodata

COPY OCUM.repo /etc/yum.repos.d/

# Install some base requirements
#RUN yum install -y --disablerepo=centos* MySQL-server MySQL-client MySQL-shared-compat node rp; yum clean all
RUN yum install -y --disablerepo=centos* mysql-community-server mysql-community-client mysql-community-libs-compat node; yum clean all

# We cannot use yum here because we force the installation of the rpm to ignore dependencies
# yumdownloaded tool is used to fetch the package link

#RUN rpm -i --nodeps `yumdownloader --urls ocie-serverbase|tail -1`

# Install some more packages
RUN yum install -y --disablerepo=centos* ocie-server ocie-au rp; yum clean all

RUN sed -i -E 's,(\. /etc/init.d/functions),SYSTEMCTL_SKIP_REDIRECT=1;\1,' /etc/init.d/rp

# That's where the ugly happens. In order to get OCUM installed properly we need to bypass the resolution
# of the local host name. With some ISPs resolving "wildcard DNS", you end up getting a public IP when
# trying to resolve the local host name of the temporary build container.
# To work around this, first we get the URL of the package installed, then we empty resolv.conf, and
# continue with the installation

RUN url=`yumdownloader --urls netapp-ocum|tail -1`; echo > /etc/resolv.conf; \
service rp start; \
mkdir -p /opt/netapp/essentials/jboss/bin/ /opt/netapp/ocum/safecopy/opt/netapp/essentials/jboss/bin/;echo -e '# These settings are only used in dev environments (ant deploy)\n\
INITIAL_HEAPSIZE="512m"\n\
MAX_HEAPSIZE="2048m"\n\
INITIAL_PERMSIZE="128m"\n\
MAX_PERMSIZE="512m"' > /opt/netapp/essentials/jboss/bin/standalone.conf.include.small;\
cp /opt/netapp/essentials/jboss/bin/standalone.conf.include.small /opt/netapp/ocum/safecopy/opt/netapp/essentials/jboss/bin/standalone.conf.include.small;\
rpm -v -ivh \
 --excludepath=/opt/netapp/ocum/safecopy/opt/netapp/essentials/jboss/bin/standalone.conf.include.small \
 --excludepath=/opt/netapp/essentials/jboss/bin/standalone.conf.include.small \
 $url 

# This is our start file
RUN echo -e '#!/bin/bash\n\
service rp start\n\
service ocieau start\n\
service ocie start\n\
tail -f /var/log/ocum/*' > /start.sh; chmod 755 /start.sh

RUN mkdir -p /opt/netapp/ocum/etc;echo -e "autosupport.enabled = false\n\
mail.smtp.host = localhost\n\
mail.smtp.port = 25\n\
mail.smtp.ssl = false\n\
initialSetupComplete = true" > /opt/netapp/ocum/etc/ocum.conf

CMD /start.sh

EXPOSE 443

#ENV VIRTUAL_HOST docker2
#ENV VIRTUAL_PROTO https

#VOLUME ["/data"]

# When the buld is done, you can log into the OCUM server, setup the wizard and run docker commit on the container to keep that "post wizard" state persistent.
