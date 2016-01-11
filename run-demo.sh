#!/bin/bash -e

#
#  Run the multi-tenant routers demo script.
#
#  Usage:  /path/to/run-demo.sh  <options>
#            where <options> = -d | --dry-run | -g | --generate
#                  -d | --dryrun   :  prints out a dry run.
#                  -c | --cleanup  :  cleanup the test environment.
#                  -g | --generate :  generates a script of commands.
#                  -x              :  run script with bash -x
#
#  Example:
#    run-demo.sh  --dry-run 
#
#    run-demo.sh  --cleanup
#
#    run-demo.sh  --generate
#
#    run-demo.sh  -d
#
#    run-demo.sh  -c
#
#    run-demo.sh  -g
#
#    run-demo.sh  -d  -g 
#
#    run-demo.sh  -x  -d  -c
#

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")


#
#  Run the demo script.
#
#  Usage:  _run_demo_script  <options>
#            where <options> = -d | --dry-run | -g | --generate
#                  -d | --dryrun   :  prints out a dry run.
#                  -c | --cleanup  :  cleanup the test environment.
#                  -g | --generate :  generates a script of commands.
#                  -x              :  run script with bash -x
#
#  Example:
#    _run_demo_script  --dry-run 
#
#    _run_demo_script  --cleanup
#
#    _run_demo_script  --generate
#
#    _run_demo_script  -d
#
#    _run_demo_script  -c
#
#    _run_demo_script  -g
#
#    _run_demo_script  -d  -g 
#
#    run-demo.sh  -x  -d  -c
#
function _run_demo_script() {
  local args=""
  local generate=0
  local debug=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -d|--dry-run)    args="--dry-run"  ;;
      -c|--cleanup)    args="--cleanup"  ;;
      -g|--generate)   generate=1;       ;;
      -x)              debug="-x"        ;;
      *) echo  "  - Unsupported option $1, ignoring ... " ;;
    esac

    shift
  done

  if [ ${generate} -eq 1 ]; then
    ${SCRIPT_DIR}/bin/demo.sh  --dry-run |  \
      grep "Running command: " |  cut -f 2- -d ':'
  else
    bash ${debug} ${DEBUG} ${SCRIPT_DIR}/bin/demo.sh  "${args}"
  fi

}  #  End of function  _run_demo_script.


#
#  main():
#

_run_demo_script  "$@"

