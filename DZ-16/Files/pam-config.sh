#!/bin/bash

apt update -y
apt install docker-compose-v2 -y

groupadd administrator
useradd -m -p $(openssl passwd -6 "poweruser") -s /bin/bash poweruser
usermod -aG administrator poweruser

useradd -m -p $(openssl passwd -6 "alex") -s /bin/bash alex
useradd -m -p $(openssl passwd -6 "gary") -s /bin/bash gary


################## Первая часть #####################
# С помощью PAM запрещаем всем за исплючением poweruser входить в систему в субботу и воскресенье

# Настраиваем правила в /etc/security/time.conf (если они еще не прописаны)
if ! grep -q "#--- My PAM rules ---" "/etc/security/time.conf"; then
	echo "" >> /etc/security/time.conf
	echo "#--- My PAM rules ---" >> /etc/security/time.conf

	# прописываем блокировать вход в систему по выходным для всех
	echo '*; *; *; !Wd0000-2400' >> /etc/security/time.conf
fi

# Настраиваем правила в /etc/pam.d/common-account (если они еще не прописаны)
if ! grep -q "#--- My PAM rules ---" "/etc/pam.d/common-account"; then
	echo "" >> /etc/pam.d/common-account
	echo "#--- My PAM rules ---" >> /etc/pam.d/common-account
	
	# если логинящийся пользователь состоит в группе administrator, то следующее правило пропускается (проверка pam_time.so пропускается)
	echo "account [success=1 default=ignore] pam_succeed_if.so user ingroup administrator" >> /etc/pam.d/common-account

	# запускается проверка модулем pam_time.so (правила из /etc/security/time.conf)
	echo "account requisite pam_time.so" >> /etc/pam.d/common-account
fi


################## Вторая часть #####################
# С помощью PAM даем возможность poweruser работать с программой docker (указанному пользователю динамически добавляем группу docker)

# Настраиваем правила в /etc/security/group.conf (если они еще не прописаны)
if ! grep -q "#--- My PAM rules ---" "/etc/security/group.conf"; then
	echo "" >> /etc/security/group.conf
	echo "#--- My PAM rules ---" >> /etc/security/group.conf

	# Пользователю poweruser (в нашем случае при входе в систему) даем группу doker (в любое время)
 	echo "*; *; poweruser; Al0000-2400; docker" >> /etc/security/group.conf
fi

# Настраиваем правила в /etc/pam.d/common-auth (если они еще не прописаны)
if ! grep -q "#--- My PAM rules ---" "/etc/pam.d/common-auth"; then
	echo "" >> /etc/pam.d/common-auth
	echo "#--- My PAM rules ---" >> /etc/pam.d/common-auth
	
	# запускаем модуль pam_group.so (правила в /etc/security/group.conf)
	echo "auth optional pam_group.so" >> /etc/pam.d/common-auth
fi

# Через PAM дать poweruseru возмозность перезапускать службу docekr (systemctl restart docker) в произвольное время, а не в момент загрузки сессии не получится
# по этому делаю это через правила /etc/sudoers
# пользователь сможет выполрять sudo systemctl restart/start/stop docker без ввода пароля

# Добавляем правило в /etc/sudoers (если оно еще не прописано)
if ! grep -q "#--- My rules ---" "/etc/sudoers"; then
	# Создаем временный sudoers и добавляем в него необходимое правило
        cp /etc/sudoers /tmp/sudoers.tmp
	echo "" >> /tmp/sudoers.tmp
	echo "#--- My rules ---" >> /tmp/sudoers.tmp
	echo "Defaults:poweruser timestamp_timeout=0" >> /tmp/sudoers.tmp
        echo "poweruser ALL=(root) NOPASSWD: /bin/systemctl restart docker, /bin/systemctl start docker, /bin/systemctl stop docker" >> /tmp/sudoers.tmp

	# Проверяем синтаксис временного файла
	visudo -cf /tmp/sudoers.tmp

        # Если всё ОК переписываем оригинал
	if [ $? -eq 0 ]; then
		mv /tmp/sudoers.tmp /etc/sudoers
		chmod 0440 /etc/sudoers
	fi
fi
