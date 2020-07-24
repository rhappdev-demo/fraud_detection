#! /bin/bash

USAGE="$0 userName:userPassword ocpUrl projectName [ pvForMysql:pvForVdb ]"
if [ "$#" -lt 3 ]; then
  echo $USAGE
  exit 1;
fi

# https://api.crc.testing:6443

# split userName and password
USER=`echo $1 | cut -d':' -f1`
USER_PASSWORD=`echo $1 | cut -d':' -f2`

OCP_URL=$2
PROJECT=$3

DELAY=30


echo "***************************"
echo "Input Parameters:"
echo -e "\tUSER: $USER"
echo -e "\tUSER_PASSWORD: $USER_PASSWORD"
echo -e "\tOCP URL: $OCP_URL"
echo -e "\tPROJECT NAME: $PROJECT"

if [ "$#" -eq 4 ]; then
  PV_MYSQL=`echo $4 | cut -d':' -f1`
  PV_VDB=`echo $4 | cut -d':' -f2`
  
  echo -e "\tMySQL PV NAME: $PV_MYSQL"
  echo -e "\tVDB PV NAME: $PV_VDB"
fi


echo -e "***************************\n"


# login as $USER
#####
echo "Logging in as: $USER ..."
oc login -u $USER -p $USER_PASSWORD $OCP_URL

echo "Create project: $PROJECT ..."
oc new-project $PROJECT

if [ "$#" -eq 4 ]; then
  echo "Creating PVCs ..."
  sed -e "s/name: name/name: csv-rdbms/g" \
-e "s/volumeName: volumeName/volumeName: $PV_VDB/g" \
-e "s/namespace: namespace/namespace: $PROJECT/g" \
scripts/pvc.yaml > /tmp/vdb-pvc.yaml

  oc create -f /tmp/vdb-pvc.yaml

  sed -e "s/name: name/name: mysql/g" \
-e "s/volumeName: volumeName/volumeName: $PV_MYSQL/g" \
-e "s/namespace: namespace/namespace: $PROJECT/g" \
scripts/pvc.yaml > /tmp/mysql-pvc.yaml

  oc create -f /tmp/mysql-pvc.yaml
fi


echo "Deploying MySQL ..."
oc new-app \
-e MYSQL_USER=user \
-e MYSQL_PASSWORD=mypassword \
-e MYSQL_DATABASE=mysqlsampledb \
-e MYSQL_ROOT_PASSWORD=mypassword \
mysql:5.7

sleep $DELAY
/bin/bash scripts/mysqlRunning.sh

echo "Modifying dc to use PVC for database ..."
oc -o yaml get dc/mysql > /tmp/mysql-dc.yaml
sed -e '/metadata:/,/labels:/{//!d;}' \
-e '/status:/,/ZZZ/d' \
/tmp/mysql-dc.yaml | awk '/containers:/ { print "      volumes:\n        - name: mysql\n          persistentVolumeClaim:\n            claimName: mysql"}1' | \
awk '/ports:/ { print "        volumeMounts:\n            - name: mysql\n              mountPath: /var/lib/mysql/data"}1' > /tmp/mysql-dc-pvc.yaml
oc apply -f /tmp/mysql-dc-pvc.yaml

sleep $DELAY
/bin/bash scripts/mysqlRunning.sh

echo "Populating MySQL ..."
POD=`oc get pod | grep mysql | grep -v deploy | cut -d' ' -f1`
oc rsync scripts $POD:/tmp/
oc exec $POD -- /bin/sh  -c  '/tmp/scripts/setupDB.sh'

echo "Setting up configmap ..."
oc policy add-role-to-user view -z default
IP=`oc get svc mysql | grep 3306 | egrep -o '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'`
sed  -e "s/127\.0\.0\.1/$IP/g" csv-rdbms-fraud/src/main/resources/application.properties > /tmp/application.properties
oc create configmap csv-rdbms-fraud --from-file=/tmp/application.properties

echo "Deploying VDB ..."
cd csv-rdbms-fraud
mvn clean -P openshift fabric8:deploy
cd ..

sleep $DELAY
/bin/bash scripts/vdbRunning.sh

echo "Updating DC for VDB ..."
oc -o yaml get dc/csv-rdbms-fraud > /tmp/vdb-dc.yaml
sed -e '/metadata:/,/labels:/{//!d;}' \
-e '/status:/,/ZZZ/d' \
/tmp/vdb-dc.yaml | awk '/containers:/ { print "      volumes:\n        - name: csv-rdbms\n          persistentVolumeClaim:\n            claimName: csv-rdbms"}1' | \
awk '/ports:/ { print "        volumeMounts:\n            - name: csv-rdbms\n              mountPath: /media"}1' > /tmp/vdb-dc-pvc.yaml
oc apply -f /tmp/vdb-dc-pvc.yaml

sleep $DELAY
/bin/bash scripts/vdbRunning.sh

echo "Copying CSV to persistent storage ..."
oc rsync resources $(oc get pods -o=jsonpath='{.items[0].metadata.name}' -l app=csv-rdbms-fraud):/media/


echo "Updating VDB Service to include Teiid JDBC port..."
oc -o yaml get svc/csv-rdbms-fraud > /tmp/vdb-svc.yaml
awk '1;/ports:/ { print"  - name: teiid\n    protocol: TCP\n    port: 31000\n    targetPort: 31000"}' \
/tmp/vdb-svc.yaml > /tmp/vdb-svc-teiid.yaml
oc apply -f /tmp/vdb-svc-teiid.yaml

echo "Checking if both data sources (MySQL and CSV) are working using ODATA..."
ODATA_URL=http://`oc get route | grep csv | egrep -o 'csv-rdbms-fraud-\S+'`/odata/csvrdbms/CreditFraud/
COUNT=`curl "$ODATA_URL"'$count'`
if [ $COUNT -eq 10000 ]; then
	echo "VDB check: OK"
else
	echo "VDB check: Failed"
	exit 2;
fi


echo "VDB setup complete."


exit 0;



