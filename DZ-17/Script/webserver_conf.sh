#!/bin/bash

NginxConf="/etc/nginx/nginx.conf"
AuditRules="/etc/audit/rules.d/my_audit.rules"
AuditPlugins="/etc/audit/plugins.d/syslog.conf"
RsyslogConf="/etc/rsyslog.d/60-audit-remote.conf"

sed -i 's|access_log /var/log/nginx/access.log;|access_log syslog:server=192.168.60.160:514,tag=nginx_access combined;|' "$NginxConf"
if ! grep -q 'error_log syslog:server=192.168.60.160:514,tag=nginx_error;' "$NginxConf"; then
	sed -i 's|error_log /var/log/nginx/error.log;|&\n\terror_log syslog:server=192.168.60.160:514,tag=nginx_error;|' "$NginxConf"
fi
systemctl restart nginx

if ! grep -q '# Control Nginx configuration file' "$AuditRules"; then
	cat <<EOF >> "$AuditRules"

-w $NginxConf -p wa -k AuditNginxConf
EOF
fi
sed -i 's|active = no|active = yes|' "$AuditPlugins"
service auditd restart

if ! grep -q 'local6.* @@192.168.60.160:514' "$RsyslogConf"; then
	cat <<EOF >> "$RsyslogConf"

module(load="imfile" PollingInterval="5")

input(type="imfile"
      File="/var/log/audit/audit.log"
      Tag="auditd"
      Severity="info"
      Facility="local6")

local6.* @@192.168.60.160:514
EOF
fi
service rsyslog restart

