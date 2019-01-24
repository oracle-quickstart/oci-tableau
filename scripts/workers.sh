#!/bin/bash -x

sleep 120
set_topology() {
    source '/tmp/secrets.properties'
    nodecount=0
    tsm topology list-nodes -u "$tsm_admin_user" -p "$tsm_admin_pass" | while read p; do
        nodecount=$((nodecount+1))
        tsm topology set-process -n "$p" -pr clustercontroller -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
        tsm topology set-process -n "$p" -pr gateway -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
        tsm topology set-process -n "$p" -pr vizportal -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
        tsm topology set-process -n "$p" -pr vizqlserver -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
        tsm topology set-process -n "$p" -pr cacheserver -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
        tsm topology set-process -n "$p" -pr searchserver -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
        tsm topology set-process -n "$p" -pr backgrounder -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
        tsm topology set-process -n "$p" -pr dataserver -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
        tsm topology set-process -n "$p" -pr dataengine -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
        tsm topology set-process -n "$p" -pr filestore -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
    done
    sleep 120
    # Run pgsql on node1 for single tableau setup else on node2
    if [ $nodecount -eq 1 ] ; then
	tsm topology set-process -n node1 -pr pgsql -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
    else
	tsm topology set-process -n node2 -pr pgsql -c 1 -u "$tsm_admin_user" -p "$tsm_admin_pass"
    fi     
    tsm pending-changes apply --ignore-prompt -iw -u "$tsm_admin_user" -p "$tsm_admin_pass"
    sleep 120
    tsm stop -u "$tsm_admin_user" -p "$tsm_admin_pass"
    if [ $nodecount -ge 3 ] ; then
    	tsm topology deploy-coordination-service -n node1,node2,node3  -u "$tsm_admin_user" -p "$tsm_admin_pass"    
    	tsm topology cleanup-coordination-service -u "$tsm_admin_user" -p "$tsm_admin_pass"
    fi    
    tsm start -u "$tsm_admin_user" -p "$tsm_admin_pass"
    tsm status -v -u "$tsm_admin_user" -p "$tsm_admin_pass"
}
set_topology
unset -f set_topology

## Created for another process to look for this file as proof of completion.
touch /tmp/workers.sh.complete
