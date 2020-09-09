oc new-project appdev-aiml-demo

# Write code to Install AMQ Streams Cluster Operator here 

# Write code to Install AMQ Streams Cluster Operator here 

oc apply -f scripts/kafka-single.yaml 

# Write code to wait for Kafka Status to become ready

oc apply -f scripts/kafka-topic-transactions.yaml 

oc apply -f scripts/kafka-topic-automode.yaml 

oc apply -f scripts/kafka-topic-manualmode.yaml 

oc extract secret/appdev-kafka-cluster-cluster-ca-cert --keys=ca.crt --to=- > ca.crt

keytool -import -trustcacerts -alias appdev-streams-cluster -file ca.crt -keystore truststore.jks -storepass password -noprompt

# Get the output of the below command and configure the SSL for kafka connection in application properties
oc get routes appdev-kafka-cluster-kafka-bootstrap -o=jsonpath='{.status.ingress[0].host}{"\n"}'

#Test if the Producer and consumer works using below command..Download kafka binaries for this

/Users/krnaraya/Downloads/kafka_2.13-2.5.0/bin/kafka-console-producer.sh --broker-list appdev-kafka-cluster-kafka-bootstrap-appdev-aiml-demo.apps.cluster-acfe.acfe.example.opentlc.com:443 --producer-property security.protocol=SSL --producer-property ssl.truststore.password=password --producer-property ssl.truststore.location=/Users/krnaraya/source/aiml_webinar/kogito-kafka-fraud-detection/truststore.jks --topic transactions

/Users/krnaraya/Downloads/kafka_2.13-2.5.0/bin/kafka-console-consumer.sh --bootstrap-server appdev-kafka-cluster-kafka-bootstrap-appdev-aiml-demo.apps.cluster-acfe.acfe.example.opentlc.com:443 --consumer-property security.protocol=SSL --consumer-property ssl.truststore.password=password --consumer-property ssl.truststore.location=/Users/krnaraya/source/aiml_webinar/kogito-kafka-fraud-detection/truststore.jks --topic automode --from-beginning

/Users/krnaraya/Downloads/kafka_2.13-2.5.0/bin/kafka-console-consumer.sh --bootstrap-server appdev-kafka-cluster-kafka-bootstrap-appdev-aiml-demo.apps.cluster-acfe.acfe.example.opentlc.com:443 --consumer-property security.protocol=SSL --consumer-property ssl.truststore.password=password --consumer-property ssl.truststore.location=/Users/krnaraya/source/aiml_webinar/kogito-kafka-fraud-detection/truststore.jks --topic manualmode --from-beginning

oc expose -n fraud-demo-dev svc/fraud-detect-classifier --hostname="http://fraud-detect-classifier-fraud-demo-dev.apps.cluster-acfe.acfe.example.opentlc.com"

kogito deploy-service kogito-kafka-fraud-detection https://github.com/krnaraya/kogito-kafka-fraud-detection

curl -d 'json={"data":{"ndarray":[["-4.47513271259153","5.4676845487781","-4.59495176285009","5.27550585077254","-11.3490285500915","-8.13869488434773","-10.2467554066001"]]}}' http://localhost:8081/predict