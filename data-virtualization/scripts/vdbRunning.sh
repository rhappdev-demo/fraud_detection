#! /bin/bash
while [ `oc get pod | grep csv-rdbms-fraud | grep deploy | grep Running | wc -l` -ne 0 ]
do
  sleep 5
done
while [ "`oc get pod | grep csv-rdbms-fraud | grep -v deploy | grep Running`" == "" ]
do
  sleep 5
done
sleep 30
echo "csv-rdbms-fraud running now."