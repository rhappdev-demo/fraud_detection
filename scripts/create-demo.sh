#!/bin/bash

set -e -u -o pipefail
declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)
declare PRJ_PREFIX="fraud-demo"
declare COMMAND="help"
declare SKIP_STAGING_PIPELINE=""
declare USER=""
declare PASSWORD=""
declare slack_webhook_url=""

valid_command() {
  local fn=$1; shift
  [[ $(type -t "$fn") == "function" ]]
}

info() {
    printf "\n# INFO: $@\n"
}

err() {
  printf "\n# ERROR: $1\n"
  exit 1
}

while (( "$#" )); do
  case "$1" in
    install|uninstall|help)
      COMMAND=$1
      shift
      ;;
    -p|--project-prefix)
      PRJ_PREFIX=$2
      shift 2
      ;;
    --user)
      USER=$2
      shift 2
      ;;
    --password)
      PASSWORD=$2
      shift 2
      ;;
    --slack-webhook-url)
      slack_webhook_url=$2
      shift 2
      ;;
    --sysdig-secure-token)
      sysdig_secure_token=$2
      shift 2
      ;;
    --skip-staging-pipeline)
      SKIP_STAGING_PIPELINE=$1
      shift 1
      ;;
    --)
      shift
      break
      ;;
    -*|--*)
      err "Error: Unsupported flag $1"
      ;;
    *) 
      break
  esac
done

declare -r dev_prj="$PRJ_PREFIX-dev"
declare -r stage_prj="$PRJ_PREFIX-stage"
declare -r cicd_prj="$PRJ_PREFIX-cicd"

command.help() {
  cat <<-EOF

  Usage:
      create-demo [COMMAND] [OPTIONS]
  
  Example:
      $DEMO_HOME/scripts/create-demo.sh install --project-prefix fraud-demo --user <USER> --password <PASSWORD> --slack-webhook-url <SLACK_WEBHOOK_URL>
  
  COMMANDS:
      install                        Sets up the demo and creates namespaces
      uninstall                      Calls cleanup script with default values
      help 

  OPTIONS:
      -p|--project-prefix [string]   Prefix to be added to demo project names e.g. PREFIX-dev
      --user [string]                User name for the Red Hat registry
      --password [string]            Password for the Red Hat registry
      --slack-webhook-url            Webhook for posting to a slack bot (pre-configured outside this script)
      --sysgid-secure-token          Sysdig Secure API Token (necessary for image scan)
      --skip-staging-pipeline        Skip installing anything into the staging project
EOF
}

command.install() {
  oc version >/dev/null 2>&1 || err "no oc binary found"

  if [[ -z "${DEMO_HOME:-}" ]]; then
    err '$DEMO_HOME not set'
  fi

  info "Creating namespaces $cicd_prj, $dev_prj, $stage_prj"
  oc get ns $cicd_prj 2>/dev/null  || { 
    oc new-project $cicd_prj 
  }
  oc get ns $dev_prj 2>/dev/null  || { 
    oc new-project $dev_prj
  }
  oc get ns $stage_prj 2>/dev/null  || { 
    oc new-project $stage_prj 
  }

  info "Create pull secret for redhat registry"
  $DEMO_HOME/scripts/util-create-pull-secret.sh registry-redhat-io --project $cicd_prj -u $USER -p $PASSWORD

  # import the s2i builder image that will be used to build our model for serving using Seldon
  info "import seldon core s2i image"
  oc import-image -n $cicd_prj seldon-builder --from=seldonio/seldon-core-s2i-python3 --reference-policy='local' --confirm

  info "Configure service account permissions for builder"
  oc policy add-role-to-user system:image-puller system:serviceaccount:$dev_prj:builder -n $cicd_prj

  info "Configure service account permissions for pipeline"
  oc policy add-role-to-user edit system:serviceaccount:$cicd_prj:pipeline -n $dev_prj
  oc policy add-role-to-user system:image-puller system:serviceaccount:$cicd_prj:pipeline -n $dev_prj
  oc policy add-role-to-user edit system:serviceaccount:$cicd_prj:pipeline -n $stage_prj

  info "Deploying CI/CD infra to $cicd_prj namespace"
  oc apply -R -f $DEMO_HOME/kube/cd -n $cicd_prj
  GOGS_HOSTNAME=$(oc get route gogs -o template --template='{{.spec.host}}' -n $cicd_prj)

  info "Deploying pipeline, tasks, and workspaces to $cicd_prj namespace"
  oc apply -f $DEMO_HOME/kube/tekton/tasks --recursive -n $cicd_prj
  oc apply -f $DEMO_HOME/kube/tekton/config -n $cicd_prj
  oc apply -f $DEMO_HOME/kube/tekton/pipelines/pipeline-workvol-pvc.yaml -n $cicd_prj
  
  if [[ -z "${slack_webhook_url}" ]]; then
    info "NOTE: No slack webhook url is set.  You can add this later by running oc create secret generic slack-webhook-secret."
  else
    oc create secret generic slack-webhook-secret --from-literal=url=${slack_webhook_url} -n $cicd_prj
  fi

  info "Deploying dev and staging pipelines"
  if [[ -z "$SKIP_STAGING_PIPELINE" ]]; then
    echo "PLACEHOLDER STAGING PIPELINE"
  else
    info "Skipping deploy to staging pipeline at user's request"
  fi
  sed "s/demo-dev/$dev_prj/g" $DEMO_HOME/kube/tekton/pipelines/fraud-model-dev-pipeline.yaml | sed "s/demo-cicd/$cicd_prj/g" | oc apply -f - -n $cicd_prj
  
  # Install pipeline resources
  sed "s/demo-dev/$dev_prj/g" $DEMO_HOME/kube/tekton/resources/model-image.yaml | oc apply -f - -n $cicd_prj
  
  # Install pipeline triggers
  oc apply -f $DEMO_HOME/kube/tekton/triggers --recursive -n $cicd_prj

  info "Initiatlizing git repository in Gogs and configuring webhooks"
  sed "s/@HOSTNAME/$GOGS_HOSTNAME/g" $DEMO_HOME/kube/config/gogs-configmap.yaml | oc create -f - -n $cicd_prj
  oc rollout status deployment/gogs -n $cicd_prj
  oc create -f $DEMO_HOME/kube/config/gogs-init-taskrun.yaml -n $cicd_prj

  # install ODH components
  declare -r arrOdhProjects=( $dev_prj )

  # Looks like ODH can't really be installed to multiple projects
  # declare -r arrOdhProjects=( $dev_prj $stage_prj )
  for prj in "${arrOdhProjects[@]}"
  do
    echo "setting up ODH in project $prj"
    oc apply -f $DEMO_HOME/kube/odh/odh-kfdef.yaml -n $prj
  done

  for prj in "${arrOdhProjects[@]}"
  do
    echo "Customizing ODH components in $prj"

    # Add appropriate singleuser notebook image to jupyter hub
    #
    # Remove other images installed by ODH by default
    echo "Removing default notebook images"
    NOTEBOOK_IS=""
    while [[ -z "${NOTEBOOK_IS}" ]]; do
      sleep 1
      echo "Looking for extraneous notebooks to remove"
      # NOTE: Due to -e and pipefail, we need to add the || true to grep since grep will error if it can't find a match (!)
      NOTEBOOK_IS=$(oc get is --no-headers -o name -n $prj 2>/dev/null | (grep s2i || true) | sed "s#^[^\/]*\/##g")
    done
    # NOTE: If ${NOTEBOOK_IS} is used bare, the command fails.  Appears to have something to do with newlines being escaped out and 
    # breaking the underlying (web) API call
    echo "Notebooks found for removal are:"
    echo "${NOTEBOOK_IS}"
    oc delete -n $prj is $(echo -n ${NOTEBOOK_IS})

    # FIXME: Change image name
    oc import-image ${prj}/demo-notebook-image --from quay.io/mhildenb/andy-notebook-image --reference-policy='local' --confirm -n $prj
    oc label is/demo-notebook-image "opendatahub.io/notebook-image"=true -n $prj

    # Reference the notebook image as a model extraction image in the cicd namespace for Tekton
    oc tag ${prj}/demo-notebook-image:latest ${cicd_prj}/extract-model:latest

    # update the notebook server config file to add a kubespawner post_start hook that will automatcially
    # clone the local gogs repo into the notebook server (persistent volume backed) filesystem
    oc patch cm jupyterhub-cfg -n $prj --type='json' -p="$(cat $DEMO_HOME/kube/odh/jupyter/jupyterhub-cfg-patch.json | sed s/demo-cicd/$cicd_prj/g)"

    while [[ -z "$(oc get dc/jupyterhub -n $prj 2>/dev/null)" ]]; do
      echo "Waiting for jupyterhub to be available"
      sleep 2
    done

    echo "Restarting jupyter hub to get new images"
    # cancel existing rollout and wait (but don't stop script on oc rollout status)
    oc rollout cancel dc/jupyterhub -n $prj
    oc rollout status dc/jupyterhub -n $prj || true
  
    # deploy a new rollout that takes in the new images (and cfg path) 
    oc rollout latest dc/jupyterhub -n $prj
    oc rollout status dc/jupyterhub -n $prj

  done        

  if [[ -z "$(oc get project gatekeeper-system 2>/dev/null)" ]]; then
    echo "Installing Open Policy Agent Gatekeeper"
    # currently pegged to version 3.1.0 beta.7, per instructions here: https://github.com/redhat-octo-security/opa-example-app
    oc apply -f $DEMO_HOME/kube/opa/gatekeeper-install.yaml
    oc -n gatekeeper-system adm policy add-scc-to-user privileged -z gatekeeper-admin
  fi

  echo "Install demo specific OPA CRDs and assets"
  # install ModelAccuracy CRD, template, and instance
  oc apply -f $DEMO_HOME/kube/opa/modelaccuracy-crd.yaml
  oc apply -f $DEMO_HOME/kube/opa/modelaccuracythreshold-template.yaml

  # wait for the AIModelAccuracyThreshold CRD to be installed
  # before we move on to the next step
  echo "Waiting for AIModelAccuracyThreshold CRD to be installed"
  while [[ -z "$(oc explain AIModelAccuracyThreshold 2>/dev/null)" ]]; do
    echo -n .
    sleep 1
  done

  sed "s/demo-cicd/$cicd_prj/g" $DEMO_HOME/kube/opa/modelaccuracythreshold.yaml | oc apply -n $cicd_prj -f - 
  
  # a template installed to the cicd project for Tekton to use in reporting model accuracy
  oc apply -f $DEMO_HOME/kube/opa/modelaccuracy-template.yaml -n $cicd_prj
  
  # give pipeline service account rights to operate on ai.devops.demo resources (to create model accuracy objects)
  oc apply -f $DEMO_HOME/kube/opa/ai.devops.demo-role.yaml -n $cicd_prj

  echo "Installing sysdig scanning assets"
  if [[ -n "${sysdig_secure_token}" ]]; then
    oc create secret generic sysdig-secret --from-literal secure-token="${sysdig_secure_token}"
  else
    echo "WARNING: No token specified for sysdig.  Image scanning will not work properly"
  fi

  # Leave user in cicd project
  echo "Setting project to $cicd_prj"
  oc project $cicd_prj

  echo "Demo elements installed successfully!"
}

command.uninstall() {
  echo "Removing demo from cluster"
  $SCRIPT_DIR/cleanup.sh -p $PRJ_PREFIX --remove-opa
}

main() {
  local fn="command.$COMMAND"
  valid_command "$fn" || {
    err "invalid command '$COMMAND'"
  }

  cd $SCRIPT_DIR
  $fn
  return $?
}

main