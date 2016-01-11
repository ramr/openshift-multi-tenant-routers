#!/bin/bash -e


SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
REPO_DIR=$(cd -P -- "${SCRIPT_DIR}/.." && pwd)

ADMIN_KUBECONFIG=${KUBECONFIG}

TEMP_OUTFILE="/tmp/demo-multi-tenant-router.out.$$"
LOGFILE="/tmp/demo-multi-tenant.log"
DEMO_KUBECONFIG="/tmp/multi-tentant-demo.kubeconfig"

DC_NAME="header-test"
SERVICE_NAME="header-test-insecure"
ROUTE_NAME="header-test-http-allow"
ROUTE_HOST="allow-http.header.test"
RESTRICTED_SCC_NAME="restricted-with-host-ports"

ROUTER_SERVICE_ACCOUNT="router"

RESTRICTED_SCC_JSON="${SCRIPT_DIR}/${RESTRICTED_SCC_NAME}.json"

EXAMPLE_REPO_DIR="${REPO_DIR}/nodejs-header-echo/openshift"
DC_JSON="${EXAMPLE_REPO_DIR}/dc.json"
SERVICE_JSON="${EXAMPLE_REPO_DIR}/insecure-service.json"
ROUTE_JSON="${EXAMPLE_REPO_DIR}/edge-secured-allow-http-route.json"

DRY_RUN=0

declare -A USERS=( [john]="jock" [paul]="macca" [george]="hari" [ringo]="ritchie" )

declare -A PROJECTS=( [john]="imagine" [paul]="wings" [george]="wilburys" \
		      [ringo]="allstarr" )

declare -A ROUTES=( [john]="plastic.ohno.band"       \
                    [paul]="bandicoot.on.the.run"    \
                    [george]="all.things.must.paas"  \
                    [ringo]="beaucoup.de.blues" )

declare -A OFFSETS=( [john]=2000 [paul]=3000 [george]=4000 [ringo]=5000 )


#
#  Log to the logfile and console.
#
#  Usage:  _log <message>
#
#  Example:
#    _log "  - Example log message here from $(hostname -s) ... "
#
function _log() {
  echo "$@" | tee -a ${LOGFILE} 

}  #  End of function  _log. 

#
#  Run command and log output to the logfile.
#
#  Usage:  lrun <command> <args> ... 
#
function _runcmd() {
  if [ ${DRY_RUN} -eq 1 ]; then
    _log "  - Running command: $@ "
    return
  fi

  _log "  - Running command: $@ " > /dev/null
  $@ > "${TEMP_OUTFILE}" 2>&1

  local status=$?
  if [ ${status} -ne 0 ]; then
    local msg="FAILED: command returned ${status}"
    _log "${msg}"

    #  Save output to the log file and also print on screen and cleanup.
    cat "${TEMP_OUTFILE}" | tee -a "${LOGFILE}"
    rm -f "${TEMP_OUTFILE}"

    return ${status}
  fi

  #  Save output to the log file and cleanup.
  cat "${TEMP_OUTFILE}" >> "${LOGFILE}"
  rm -f "${TEMP_OUTFILE}"

  return ${status}

}  #  End of function  _runcmd. 


#
#  Setup the demo environment.
#
#  Usage:  _setup_demo_env
#
function _setup_demo_env() {
  echo "" > "${LOGFILE}"
  _log "  - Logfile = ${LOGFILE}"

  #  Copy over kubeconfig, so that we can have the user login context
  #  updated in the demo copy.
  cp "${ADMIN_KUBECONFIG}" "${DEMO_KUBECONFIG}"
  export KUBECONFIG="${DEMO_KUBECONFIG}"

  for username in "${!USERS[@]}"; do
    local creds="${USER[${username}]}"
    local project="${PROJECTS[${username}]}"
    local routefile="/tmp/route-${username}.json"
    local route="${ROUTES[${username}]}"

    #  Be the admin, so that we can "become" the user.
    _runcmd  oc login -u system:admin -n default

    _log "  - Creating and logging in as user ${username} ... "
    if _runcmd  oc get user "${username}" ; then
      _log "  - User ${username} already exists."
      _runcmd  oc login -u "${username}" -p "${creds}"
    else
      _runcmd  oc login -u "${username}" -p "${creds}"
    fi

    _log "  - Creating project ${project} ... "
    if _runcmd  oc get project "${project}" ; then
      _log "  - Project ${project} already exists."
      _runcmd  oc project "${project}"
    else
      _runcmd  oc new-project "${project}" > /dev/null
    fi

    #  As per https://github.com/ramr/nodejs-header-echo repo, create a
    #  deployment, an insecure service and the route.
    _log "  - Creating dc/pods ${DC_NAME} in project ${project} ... "
    if _runcmd  oc get dc "${DC_NAME}" -test -n "${project}" ; then
      _log "  - Deployment ${DC_NAME} already exists, recreating ... "
      _runcmd  oc delete -n "${project}" -f "${DC_JSON}"
    fi

    _runcmd  oc create -n "${project}" -f "${DC_JSON}"

    _log "  - Creating service ${SERVICE_NAME} in project ${project} ... "
    if _runcmd  oc get service "${SERVICE_NAME}" -n "${project}" ; then
      _log "  - Service ${SERVICE_NAME} already exists, recreating ... "
      _runcmd  oc delete -n "${project}" -f "${SERVICE_JSON}"
    fi

    _runcmd  oc create -n "${project}" -f "${SERVICE_JSON}"


    _log "  - Generating route file ${routefile} for route ${route} ... "
    sed "s#${ROUTE_HOST}#${route}#g;" "${ROUTE_JSON}" > "${routefile}"

    _log "  - Creating route ${route} in project ${project} ... "

    if _runcmd  oc get route "${ROUTE_NAME}" -n "${project}" ; then
      _log "  - Route ${ROUTE_NAME} already exists, recreating ... "
      _runcmd  oc delete route "${ROUTE_NAME}" -n "${project}"
    fi

    _runcmd  oc create -n "${project}" -f "${routefile}"  || :

    _runcmd  oc get routes -n "${project}"
  done

}  #  End of function  _setup_demo_env.


#
#  Setup multiple routers (one for each of the users).
#
#  Usage:  _setup_routers
#
#  Example:
#    _setup_routers
#
function _setup_routers() {
  local router_args="--credentials=${ADMIN_KUBECONFIG}  --latest-images  \
                     --service-account=router --host-network=false       \
		     --replicas=1"

  _log ""
  _runcmd  oc login -u system:admin -n default

  _log "  - Creating scc ${RESTRICTED_SCC_NAME} ... "
  if _runcmd  oc get scc "${RESTRICTED_SCC_NAME}" ;  then
    _log "  - SCC ${RESTRICTED_SCC_NAME} already exists, reusing ... "
  else
    _runcmd  oc create -f "${RESTRICTED_SCC_JSON}"
  fi

  for username in "${!USERS[@]}"; do
    local name="router-${username}"
    local route="${ROUTES[${username}]}"
    local project="${PROJECTS[${username}]}"
    local offset="${OFFSETS[${username}]}"

    local hostport80=$((offset + 80))
    local hostport443=$((offset + 443))
    local offsetport1936=$((offset + 936))  # offsets are 1000 off, so ...

    local port_args="--ports=80:${hostport80},443:${hostport443}"
    local stats_port_arg="--stats-port=${offsetport1936}"

    local safile="/tmp/router-${username}-service-account.json"
    local acct="system:serviceaccount:${project}:${ROUTER_SERVICE_ACCOUNT}"

    echo '{ "kind": "ServiceAccount", "apiVersion": "v1",
            "metadata": { "name": "router" }
	  }' > "${safile}"

    _log  "  - Creating service account ${ROUTER_SERVICE_ACCOUNT} ... "
    if _runcmd  oc get sa "${ROUTER_SERVICE_ACCOUNT}" -n "${project}" ; then
      _log "  - Service account ${ROUTER_SERVICE_ACCOUNT} already exists in project ${project}, deleting ... "
       _runcmd  oc delete -n "${project}" -f "${safile}"
    fi

    _runcmd  oc create -n "${project}" -f "${safile}"

    _log "  - Running command: oc get scc ${RESTRICTED_SCC_NAME} -o json | jq \".users |= .+ [\\\"${sa}\\\"]\" |  oc replace scc -f -"
    if ! oc get scc "${RESTRICTED_SCC_NAME}" -o json |   \
	   grep "${acct}" > /dev/null ; then 
        _log "  - Adding ${acct} to SCC ${RESTRICTED_SCC_NAME} ... " 
       oc get scc "${RESTRICTED_SCC_NAME}" -o json |  \
         jq ".users |= .+ [\"${acct}\"]" |  oc replace scc -f -
    fi

    _log  "  - Starting up router in project ${project} ... "
    _runcmd  oadm router "${name}" -n "${project}"  ${router_args}  \
                                   ${port_args} ${stats_port_arg}

    local cip="oc describe pod ${name} | grep '^IP:' | awk '{print $2}'"

    _log  "  - To test the router use either of these curl commands: "
    for endpoint in "\$(${cip})" "127.0.0.1:${hostport80}"; do
      _log  "      curl -H \"Host: ${route}\" http://${endpoint}/"
    done

  done

}  #  End of function  _setup_routers.


#
#  Cleanup the test environment.
#
#  Usage:  _cleanup_test_env
#
#  Example:
#    _cleanup_test_env
#
function _cleanup_test_env() {
  for username in "${!USERS[@]}"; do
    local project="${PROJECTS[${username}]}"

    _log  "  - Deleting project ${project} ... "
    _runcmd  oc delete project ${project} || :

    _log  "  - Deleting user ${username} ... "
    _runcmd  oc delete user ${username} || :
  done

  _log "  - Cleaned up test environment. "

}  #  End of function  _cleanup_test_env.


#
#  Cleanup the demo script artifacts.
#
#  Usage:  _cleanup
#
#  Example:
#    _cleanup
#
function _cleanup() {
  for username in "${!USERS[@]}"; do
    for fname in "${TEMP_OUTFILE}"  "${DEMO_KUBECONFIG}"   \
	         "/tmp/route-${username}.json"  \
	         "tmp/router-${username}-service-account.json"; do
      [ -f "${fname}" ]  &&  rm -f "${fname}"
    done
  done

  _log "  - Clean up completed. "

}  #  End of function  _cleanup.


#
#  Run the demo script.
#
#  Usage:  _run_demo
#
#  Example:
#    _run_demo
#
function _run_demo() {

  [ "$1" = "--dry-run" ]  &&  DRY_RUN=1

  if [ "$1" = "--cleanup" ]; then
    _cleanup_test_env
    exit 0
  fi

  _setup_demo_env

  _setup_routers

  _cleanup

}  #  End of function  _run_demo.


#
#  main():
#

_run_demo "$@"

