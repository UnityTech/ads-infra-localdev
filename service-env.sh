#!/bin/bash

ACTION=$1

# Actions : 

  # Setup - Define routes to PODs
  # Sync - deploys/updates your manifest and exports SERVICE_PORT variables
  # Teardown - destroys MK, gets rid of routes

# This is just a trick to handle differences in the "route" command
# which has different syntax in Linux and OSX
GW=""
RDELETE="delete"
if [ -f /etc/issue ] ; then
  GW="gw"
  RDELETE="del"
fi

MKUBE_IP=$(minikube ip)

# Migrate this guy to setup/teardown
if [ -z "$ACTION" ] ; then
  echo "Please specify an action"
  echo "Usage: ./service-env.sh [setup|sync|teardown]"
  exit 13
fi

function get_endpoint_ip() {
  SERVICE=$1
  ENDPOINT=$(kubectl describe svc $SERVICE | grep Endpoint | head -n1 | awk -F':' '{print $2}' | sed 's/\s//g')
  echo $ENDPOINT
}

function setup { 
  minikube ssh "sudo sysctl -w net.ipv4.ip_forward=1"

  # Then, set the host machine (user's laptop) routes to go there
  sudo route add -net 10.0.0.0/24 $GW $MKUBE_IP
  sudo route add -net 172.17.0.0/16 $GW $MKUBE_IP

  # If there's anything running at all at this point, let's also setup the env vars, why not?
  sync
}

function sync {
  TEARDOWN=$1
  # Goal : export SERVICE_PORTNAME=ENDPOINTIP:PORT
  SVC_JSON=$(kubectl get services -o json)
  for SERVICE in $( echo $SVC_JSON | jq '.items | .[] | .metadata.name' | sed 's/\"//g') ; do

    ENDPOINT_IP=$(get_endpoint_ip $SERVICE)

    for PORT_NAME in $(echo $SVC_JSON | jq ".items[] | select (.metadata.name == \"${SERVICE}\") | .spec.ports[] | .name" | sed 's/\"//g') ; do
      PORT_NUMBER=$(echo $SVC_JSON | jq ".items[] | select (.metadata.name == \"${SERVICE}\") | .spec.ports[] | select (.name == \"${PORT_NAME}\") | .port")
      # Temptation to embed this logic in the eval one-liner, but doing this for readability
      VAR_NAME=$(echo ${SERVICE}_${PORT_NAME} | awk '{print toupper($0)}')
      # Adding this logic here rather than in another function. First parameter messes with it.
      if [ -n "$TEARDOWN" ] ; then
        echo "Forgetting about $VAR_NAME"
        unset ${VAR_NAME}
      else
        # Grand finale in the normal case (setup)
        echo "Setting up ${VAR_NAME} - ${ENDPOINT_IP}:${PORT_NUMBER}"
        eval $(echo "export ${VAR_NAME}=${ENDPOINT_IP}:${PORT_NUMBER}")
      fi
    done
  done
}

function teardown {
  # Undo everything from the setup. Right now, not a lot :-)
  sudo route $RDELETE -net 10.0.0.0/24 $GW $MKUBE_IP
  sudo route $RDELETE -net 172.17.0.0/16 $GW $MKUBE_IP
  sync teardown
}

if [ $ACTION == "setup" ] ; then
  setup
fi
if [ $ACTION == "sync" ] ; then
  sync $SERVICE
fi
if [ $ACTION == "teardown" ] ; then
  teardown
  exit
fi


# This is bad. But it could be worse (look at the repo's very first commit working state - disaster in OSX)
#  What we're doing here is pretty much giving the user a sub-shell from our script (which is already a sub-shell of the session running it)
#    Not great as you "lose" the history, but is the only sane way that we can enforce BASH syntax. If you want to keep the history uncomment below :
#history -w

# This assumes that bash is in the $PATH. Sometimes better than assuming full path
bash
# Just a protection/last resort guessing if bash is not in $PATH :
if [ "$?" != "0" ] ; then
  /bin/bash
fi
# TODO: Find another way to prevent session nesting after multiple actions are ran