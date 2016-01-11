openshift-multi-tenant-routers-demo
===================================
Demo repository to show how to run multiple routers on a single OpenShift
installation/node.


Demo
----
1. Start your OpenShift cluster as you would normally. Instructions will
   vary depending on how you do this in your environment. Example for a
   development environment, you can do this as follows:

        $  export WORKAREA="/home/ramr/workarea";
        $  export GOPATH="${WORKAREA}"

        $  mkdir -p "${WORKAREA}/src/github.com/openshift"
        $  cd "${WORKAREA}/src/github.com/openshift"
        $  git clone https://github.com/openshift/origin.git

        $  cd origin
        $  make  # or make release to also build the images

        $  nohup ./_output/local/bin/linux/amd64/openshift start &> /tmp/openshift.log &


2. Create a router service account and add it to the privileged SCC.

        $  echo '{ "kind": "ServiceAccount", "apiVersion": "v1", "metadata": { "name": "router" } }' | oc create -f -


        Either manually edit the privileged SCC and add the router account.

        $  oc edit scc privileged
        #  ...
        #  users:
        # - system:serviceaccount:openshift-infra:build-controller
        # - system:serviceaccount:default:router

        Or you can use jq to script it:

        $  sudo yum install -y jq
        $  oc get scc privileged -o json |
             jq '.users |= .+ ["system:serviceaccount:default:router"]' |
	     oc replace scc -f -


3.  Run the demo script to create 4 different router environments running
    scoped to and serving 4 different user namespaces.

        $  make run



Cleanup Demo Environment
------------------------
Just run `make clean` to cleanup the demo environment - projects, pods,
services, routers and users.

        $  make clean

