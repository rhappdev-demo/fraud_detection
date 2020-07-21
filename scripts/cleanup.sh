#!/bin/bash
declare PROJECT_BASE="fraud-demo"
declare FORCE=""
declare REMOVE_OPA=""

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
    -f|--force)
      FORCE="true"
      shift 1
      ;;
    -*|--*)
      err "Error: Unsupported flag $1"
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
  oc delete -f $DEMO_HOME/kube/opa/modelaccuracythreshold.yaml

  oc delete -f $DEMO_HOME/kube/opa/gatekeeper-install.yaml
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
 
if [[ ! -z "$REMOVE_OPA" ]]; then
  opa-clean
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

    # actually delete the project
    oc delete project $PROJECT

    if [[ ! -z "$FORCE" ]]; then
        force-clean $PROJECT
    fi
done

if [[ ! -z "$PROXY_PID" ]]; then
    echo "closing proxy"
    kill $PROXY_PID
fi

