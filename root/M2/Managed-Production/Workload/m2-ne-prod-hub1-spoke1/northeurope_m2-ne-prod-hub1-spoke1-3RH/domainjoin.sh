#!/bin/bash

yum install yum-cron -y
systemctl enable yum-cron.service
yum install realmd sssd krb5-workstation krb5-libs samba-common-tools PackageKit -y

systemctl enable realmd

DOMAINNAME='M2-ADDS.LOCAL'
DOMAINJOINUSERNAME='uday@M2-ADDS.LOCAL'
DOMAINJOINPASSWORD='!!123abc!!123abc'

OUTFILE=/var/lib/waagent/addj.sh

cat << addj > $OUTFILE
#!/bin/bash
set -e
if [ -e /var/log/addj.success ]
then
  echo "File Already exists at /var/log/addj.success "
else
  realm discover $DOMAINNAME
  echo '$DOMAINJOINPASSWORD' | kinit $DOMAINJOINUSERNAME
  realm join --verbose $DOMAINNAME
  touch /var/log/addj.success
fi

addj

chmod +x $OUTFILE

#Creating Unit
cat <<domainjoinunit > /usr/lib/systemd/system/addj.service
[Unit]
After=realmd.service

[Service]
ExecStart=/var/lib/waagent/addj.sh

[Install]
WantedBy=default.target
domainjoinunit

systemctl enable addj.service
reboot -f 