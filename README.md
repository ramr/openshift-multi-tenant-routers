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


2.  Run the demo script to create 4 different router environments running
    scoped to and serving 4 different user namespaces.

        $  make demo



Cleanup Demo Environment
------------------------
Just run `make clean` to cleanup the demo environment - projects, pods,
services, routers and users.

        $  make clean

