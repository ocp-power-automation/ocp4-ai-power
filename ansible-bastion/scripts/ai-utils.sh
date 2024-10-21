# ! /usr/bin/bash
# utility calls to get different data from assisted service

API_TOKEN=$(sed  's/"\*/"/g' ~/workdir-ocp4-agent/.openshift_install_state.json | jq -r '."gencrypto.AuthConfig".AgentAuthToken')
API_URL=http://${SERVER_IP}:8090/api/assisted-install/v2

rest_call() {
    COMPONENT=$1
    RESULT=$(curl --silent --fail ${API_URL}/${COMPONENT} -H "Authorization: ${API_TOKEN}")
}

get-version-info() {
    echo "OCP versions at ${API_URL}"
    rest_call "openshift-versions"
    echo ${RESULT} | jq .
}

get-addition-info() {
    get-version-info
    OCP_VERSION=$(echo ${RESULT} | jq .display_name)

    echo "AI components:"
    rest_call "component-versions"
    echo ${RESULT} | jq .

    echo "AI release sources:"
    rest_call "release-sources"
    echo ${RESULT} | jq .

    echo "AI  support ARCHs: openshift_version=${OCP_VERSION}"
    rest_call "support-levels/architectures?openshift_version=${OCP_VERSION}"
    echo ${RESULT} | jq .

    echo "AI support features: openshift_version=${OCP_VERSION}"
    rest_call "support-levels/features?openshift_version=${OCP_VERSION}"
    echo ${RESULT} | jq .
}

get-infra-id() {
    echo "# Get INFRA_HREF"
    rest_call "infra-envs"
    INFRA_ID=$(echo ${RESULT} | jq  '.[] | { href }' | grep "href" | awk -F'"' '{print $4}' | awk -F'/' '{print $6}')
    export INFRA_HREF="infra-envs/${INFRA_ID}"
    #echo "INFRA_HREF: $INFRA_HREF"
}

get-clusterid() {
    rest_call "clusters"
    export CLUSTER_ID=$(echo ${RESULT} | jq '.[0].id' | tr -d '"')
    echo "# CLUSTER_ID: ${CLUSTER_ID}"
}

get-clusters() {
    echo "Cluster status info:"
    rest_call "clusters"
    echo ${RESULT} | jq '.[] | [.id, .name, .base_dns_domain, .enabled_host_count,  .progress.finalizing_stage_percentage, .status_info]'
}

get-infra-envs() {
    echo "Infra-env info:"
    rest_call "infra-envs"
    echo ${RESULT} | jq '.'
}

get-events() {
    echo "assisted events:"
    get-infra-id
    get-clusterid
    rest_call "events?cluster_id=$CLUSTER_ID"
    echo ${RESULT} | jq '.[-10:]' | jq '.[] | [.event_time, .name, .message]'
}

get-hosts() {
    get-infra-id
    echo "All host status:"
    #curl --silent --fail ${API_URL}${INFRA_HREF}/hosts | jq -r '.[] | select(.requested_hostname=="${NODE0_NAME}") | .inventory' | jq .
    rest_call "${INFRA_HREF}/hosts"
    echo ${RESULT} | jq '.[] | [.id, .requested_hostname, .status]'
    #echo ${RESULT} | jq '.[] | select(.requested_hostname|test("^master*")) | [.id, .requested_hostname, .status]'
}

if [[ $# -eq 0 ]]; then
    get-version-info
    OCP_VERSION=$(echo ${RESULT} | jq . | grep "display_name" | awk -F'"' '{print $4}')
    echo "Set the value for assisted_ocp_version and assisted_rhcos_version to ${OCP_VERSION} in vars file"
else
    case $1 in
        "infra-envs")
            get-infra-envs
            ;;
        "clusters")
            get-clusters
            ;;
        "hosts")
            get-hosts
            ;;
        "events")
            get-events
            ;;
    esac
fi


