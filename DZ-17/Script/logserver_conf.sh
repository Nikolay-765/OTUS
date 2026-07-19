#!/bin/bash

RsyslogDir="/var/log/rsyslog"
RsyslogConf="/etc/rsyslog.conf"

if [ ! -d "$RsyslogDir" ]; then
	mkdir -p "$RsyslogDir"
fi

if [ "$(stat -c '%U:%G' "$RsyslogDir" 2>/dev/null)" != "syslog:adm" ]; then
	chown -R syslog:adm "$RsyslogDir"
fi

sed -i 's/\#module(load="imudp")/module(load="imudp")/g' "$RsyslogConf"
sed -i 's/\#input(type="imudp" port="514")/input(type="imudp" port="514")/g' "$RsyslogConf"
sed -i 's/\#module(load="imtcp")/module(load="imtcp")/g' "$RsyslogConf"
sed -i 's/\#input(type="imtcp" port="514")/input(type="imtcp" port="514")/g' "$RsyslogConf"


if ! grep -q "# Add remote logs" "$RsyslogConf"; then
	cat <<EOF >> "$RsyslogConf"

# Add remote logs
template(name="RemoteLogs" type="string" string="$RsyslogDir/%HOSTNAME%/%PROGRAMNAME%.log")
if (\$fromhost-ip != '127.0.0.1' and \$fromhost-ip != '::1') then {
    action(type="omfile" dynaFile="RemoteLogs")
    stop
}

EOF

fi

systemctl restart rsyslog