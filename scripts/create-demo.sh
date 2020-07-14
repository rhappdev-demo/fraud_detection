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
    install|uninstall|start)
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
      demo [command] [options]
  
  Example:
      demo install --project-prefix mydemo
  
  COMMANDS:
      install                        Sets up the demo and creates namespaces
      uninstall                      Deletes the demo namespaces
      help                           Help about this command

  OPTIONS:
      -p|--project-prefix [string]   Prefix to be added to demo project names e.g. PREFIX-dev
      --user [string]                User name for the Red Hat registry
      --password [string]            Password for the Red Hat registry
      --slack-webhook-url            Webhook for posting to a slack bot

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
      NOTEBOOK_IS=$(oc get is --no-headers -o name -n $prj | (grep s2i || true) | sed "s#^[^\/]\+\/##g")
    done
    # NOTE: If ${NOTEBOOK_IS} is used bare, the command fails.  Appears to have something to do with newlines being escaped out and 
    # breaking the underlying (web) API call
    oc delete -n $prj is $(echo ${NOTEBOOK_IS})

    # FIXME: Change image name
    oc import-image ${prj}/andy-notebook-image --from quay.io/mhildenb/andy-notebook-image --reference-policy='local' --confirm -n $prj
    oc label is/andy-notebook-image "opendatahub.io/notebook-image"=true -n $prj

    # Reference the notebook image as a model extraction image in the cicd namespace for Tekton
    oc tag ${prj}/andy-notebook-image:latest ${cicd_prj}/extract-model:latest

    # update the notebook server config file to add a kubespawner post_start hook that will automatcially
    # clone the local gogs repo into the notebook server (persistent volume backed) filesystem
    oc patch cm jupyterhub-cfg -n $prj --type='json' -p="$(cat $DEMO_HOME/kube/odh/jupyter/jupyterhub-cfg-patch.json)"

    while [[ -z "$(oc get dc/jupyterhub -n $prj 2>/dev/null)" ]]; do
      echo "Waiting for jupyterhub to be available"
      sleep 2
    done

    echo "Restarting jupyter hub to get new images"
    oc rollout cancel dc/jupyterhub -n $prj
    # wait for the cancel to take effect
    sleep 5
    oc rollout latest dc/jupyterhub -n $prj
    oc rollout status dc/jupyterhub -n $prj

  done        

  # Leave user in cicd project
  oc project $cicd_prj

}

command.uninstall() {
  $SCRIPT_DIR/cleanup.sh -p $PRJ_PREFIX
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