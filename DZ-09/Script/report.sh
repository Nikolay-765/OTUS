#!/bin/bash

readonly EmailAddress="nikolay_ma@mail.ru" # Email, куда шлем отчеи
readonly WatchingLog="/var/log/test.log" # Просматриваемый журнал WEB сервера

readonly AuxiliaryDir="./report" # Вспомогательная директория скрипта
readonly ReportFile="$AuxiliaryDir/report.txt" # Файл, где формируется отчет перед отправкой (прикрепляется к письму)
readonly PrevReportDateFile="$AuxiliaryDir/previousreportdate.tmp" # Файл, где храниться дата и время формирования предыдущего отчета
readonly FileReferencePoint="$AuxiliaryDir/referencepoint.tmp" # Файл, где храниться последняя строка, обработанная во время формирования предыдущего отчета (точка отчсета для нового отчета)
readonly LogOfScript="$AuxiliaryDir/report.log" # Файл журнал работы скрипта

readonly FileSelection="/tmp/tmpfile.log" # Файл, формируется выборка из $WatchingLog с новыми данными для последующего анализа
readonly FileLockFlag="/tmp/flagscript.lock" # Файл-флаг, использующийся при проверке, что скрипт не запущен

# Проверяем, что скринт не запущен
exec 777> $FileLockFlag
if ! flock -n 777; then
	echo "$(date +"%Y-%m-%d %H:%M:%S") - Script alredy running !!!" >> $LogOfScript
	exit 1
fi

if ! [ -f "$WatchingLog" ]; then
	echo "$(date +"%Y-%m-%d %H:%M:%S") - Log file: $WatchingLog not found" >> $LogOfScript
	exit 2
fi

if ! [ -d "$AuxiliaryDir" ]; then
	if mkdir $AuxiliaryDir; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") - Warning: Make directory: $AuxiliaryDir" >> $LogOfScript
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") - Error: Can't make directory: $AuxiliaryDir" >> $LogOfScript
		exit 3
	fi
fi

# Создаем выборку из $WatchingLog с которой и будем дальше работать
# Выборка берется с последней обработанной строки $FileLastString,
# если в $FileLastString пусто то считаем, что скрипт ранее не запускался и обрабатываем весь лог 
# если строка из $FileLastString в $WatchingLog не находится, то считаем, что лог частично зачищался (точка отсчета потеряна) и обрабатываем весь лог
if [ -s "$FileReferencePoint" ]; then
       	ReferencePoint=$(<$FileReferencePoint)
#	echo $ReferencePoint
	if grep -Fq "$ReferencePoint" "$WatchingLog"; then
		awk -v s="$ReferencePoint" 'flag { print } $0 == s { flag=1 }' $WatchingLog > $FileSelection
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") - Warning: Point of reference in logfile not found" >> $LogOfScript
		cp $WatchingLog $FileSelection
	fi
else
	echo "$(date +"%Y-%m-%d %H:%M:%S") - Warning: This is first start of script" >> $LogOfScript
	cp $WatchingLog $FileSelection 
fi

# Формируем отчет на основе выборки из $FileSelection
NewReportDate=$(date +"%Y-%m-%d %H:%M:%S")
echo "Report was created: $NewReportDate" > $ReportFile

if [ -f $PrevReportDateFile ]; then
	PrevReportDate=$(<$PrevReportDateFile)
else
	PrevReportDate="Never"
fi

echo "Previous report was created: $PrevReportDate" >> $ReportFile
if ! [ -s "$FileSelection" ]; then
        echo "Nothing happened during this period" >> $ReportFile
else
        echo "Log file have $(wc -l < $FileSelection) new events from $(head -n 1 $FileSelection | awk -F'[][]' '{print $2}' ) to $(tail -n 1 $FileSelection | awk -F'[][]' '{print $2}' )" >> $ReportFile

        echo "Statistics of 5 IP, that generate the most quantity requests:" >> $ReportFile
        awk '{print $1}' $FileSelection | sort | uniq -c | sort -nr | head -5 | awk '{print "\t" $2"\t - "$1}' >> $ReportFile

        echo "Statistics of 5 URLs with the highest number of requests:" >> $ReportFile
        awk '{print $7}' $FileSelection | sort | uniq -c | sort -rn | head -n 5 | awk '{print "\t" $2 "\t - " $1}' >> $ReportFile

        echo "Statistics of HTTP response code:" >> $ReportFile
        awk '{print $9}' $FileSelection | sort | uniq -c | sort -rn | awk '{print "\tcode: " $2 "\t - " $1}' >> $ReportFile

        echo "Statistics of server/client error with information on request sources that caused them:" >> $ReportFile
        awk '$9 >= 400 {print $1, $9}' $FileSelection | sort | uniq -c | sort -nr | awk '{print "\t" $1 "\t" $2 "\t  (code: " $3 ")"}' >> $ReportFile
fi

# Отправляем отчет на Email 
echo -e "Report was created: $NewReportDate \nPrevious report was created: $PrevReportDate" | mutt -s "Report of cheking WEB server logs" -a $ReportFile -- "$EmailAddress"
if [ $? -eq 0 ]; then
	echo "$(date +"%Y-%m-%d %H:%M:%S") - Report was sent successfully"  >> $LogOfScript
	LastStringSelection=$(tail -n 1 $FileSelection)
	if [ -n "$LastStringSelection" ]; then
		echo "$LastStringSelection" > $FileReferencePoint
	fi
	echo "$NewReportDate" > $PrevReportDateFile
else
	echo "$(date +"%Y-%m-%d %H:%M:%S") - Warning: Report wasn't sent" >> $LogOfScript
	rm -f $FileSelection
	rm -f $FileLockFlag
	exit 4
fi

rm -f $ReportFile
rm -f $FileSelection
rm -f $FileLockFlag
