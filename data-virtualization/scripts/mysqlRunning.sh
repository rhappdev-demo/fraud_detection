#! /bin/bash

echo "Waiting for MySQL to initialise..."
while [ "`oc get pod | grep mysql | grep -v deploy | grep Running`" == "" ]
do
  sleep 5
done
sleep 30
echo "MySQL atabase running now."