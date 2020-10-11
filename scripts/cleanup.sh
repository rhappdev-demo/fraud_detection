#!/bin/bash
declare PROJECT_BASE="fraud-demo"
declare FORCE=""
declare REMOVE_OPA=""
declare REMOVE_SELDON=""
declare REMOVE_ODH=""

while (( "$#" )); do
  case "$1" in
    -p|--project-prefix)
      PROJECT_BASE=$2
      shift 2
      ;;
    --remove-opa)
      REMOVE_OPA="true"
      shift
      ;;
    --remove-seldon)
      REMOVE_SELDON="true"
      shift
      ;;
    --remove-odh)
      REMOVE_ODH="true"
      shift
      ;;
    -f|--force)
      FORCE="true"
      shift 1
      ;;
    -*|--*)
      echo "Error: Unsupported flag $1"
      ;;
    *) 
      break
  esac
done

opa-clean() {
  # delete created resources before deleting the installation/namespace
  # per the instructions here: https://github.com/open-policy-agent/gatekeeper#uninstallation
  oc delete -f $DEMO_HOME/kube/opa/modelaccuracy-crd.yaml
  oc delete -f $DEMO_HOME/kube/opa/modelaccuracythreshold-template.yaml
  # oc delete -f $DEMO_HOME/kube/opa/modelaccuracythreshold.yaml

  oc delete -f $DEMO_HOME/kube/opa/gatekeeper-install.yaml
}

uninstall-operator() {
  local OPERATOR_NAME=$1

  local CURRENT_OPERATOR_CSV=$(oc get sub ${OPERATOR_NAME} -n openshift-operators -o yaml | grep "currentCSV: ${OPERATOR_NAME}" | sed "s/.*currentCSV: //")

  oc delete sub ${OPERATOR_NAME} -n openshift-operators
  oc delete csv ${CURRENT_OPERATOR_CSV} -n openshift-operators
}

seldon-clean() {
    # uninstall the operator based on our subscription
    echo "Unsubscribing from the seldon operator"
    uninstall-operator seldon-operator

    # unsubscribing from the operator does not appear to clean up the CRD
    echo "Removing orphaned seldon crd"
    oc delete crd/seldondeployments.machinelearning.seldon.io

    # cleanup and install plans 
    echo "Removing orphaned install plans"
    oc delete ip -n openshift-operators $(oc get ip -A | grep seldon | awk '{print $2}')
}

odh-clean() {
    # uninstall the operator based on our subscription
    echo "Unsubscribing from the odh operator"
    uninstall-operator opendatahub-operator 

    # unsubscribing from the operator does not appear to clean up the CRD
    echo "Removing orphaned kfdef crd"
    oc delete crd/kfdefs.kfdef.apps.kubeflow.org

    # cleanup and install plans 
    echo "Removing orphaned install plans"
    oc delete ip -n openshift-operators $(oc get ip -A | grep odh | awk '{print $2}')
}

# Assumes proxy has been setup
force-clean() {
    declare NAMESPACE=$1

    echo "Force removing project $NAMESPACE"

    oc get namespace $NAMESPACE -o json | jq '.spec = {"finalizers":[]}' > /tmp/temp.json
    curl -k -H "Content-Type: application/json" -X PUT --data-binary @/tmp/temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
    rm /tmp/temp.json
}

# declare an array
arrSuffix=( "dev" "stage" "cicd" )
 
if [[ -n "$REMOVE_OPA" ]]; then
  opa-clean
fi

if [[ -n "$REMOVE_SELDON" ]]; then
  seldon-clean
fi

PROXY_PID=""
if [[ ! -z "$FORCE" ]]; then
    echo -n "opening proxy"

    oc proxy &
    PROXY_PID=$!
fi

# for loop that iterates over each element in arr
for i in "${arrSuffix[@]}"
do
    echo "Deleting $i"
    declare PROJECT="${PROJECT_BASE}-${i}"

    if [[ -z "$(oc get project ${PROJECT} 2>/dev/null)" ]]; then
        echo "Project $PROJECT already removed"
        continue
    fi

    if [[ $i == "dev" ]]; then
      echo "Removing dev specific resources"
      oc delete kfdef --all --wait=true -n ${PROJECT}
    fi

    # actually delete the project
    oc delete project $PROJECT

    if [[ ! -z "$FORCE" ]]; then
        force-clean $PROJECT
    fi
done

if [[ -n "$REMOVE_ODH" ]]; then
  odh-clean
fi

if [[ ! -z "$PROXY_PID" ]]; then
    echo "closing proxy"
    kill $PROXY_PID
fi

