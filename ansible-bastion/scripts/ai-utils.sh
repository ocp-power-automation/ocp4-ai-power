# ! /usr/bin/bash
# utility calls to get different data from assisted service

API_URL=http://${SERVER_IP}:8090/api/assisted-install/v2

echo "AI components:"
curl -s ${API_URL}/component-versions | jq .

echo "AI OCP versions:"
curl -s ${API_URL}/openshift-versions | jq .


get-addition-info() {
    OCP_VERSION=$(curl -s ${API_URL}/openshift-versions | jq .display_name)

    echo "AI release sources:"
    curl -s ${API_URL}/release-sources | jq .

    echo "AI  support ARCHs: openshift_version=${OCP_VERSION}"
    curl -s ${API_URL}/support-levels/architectures?openshift_version=${OCP_VERSION} | jq .

    echo "AI support features: openshift_version=${OCP_VERSION}"
    curl -s ${API_URL}/support-levels/features?openshift_version=${OCP_VERSION} | jq .
}

get-infra() {
    echo "# Get INFRA_HREF"
    INFRA_HREF=$(curl --silent --fail ${API_URL}/infra-envs | jq  '.[] | { href }' | grep "href" | awk -F'"' '{print $4}' )
    echo "INFRA_HREF: $INFRA_HREF"
}

get-clusterid() {
    export CLUSTER_ID=$(curl --silent --fail "${API_URL}/clusters/" | jq '.[0].id' | tr -d '"')
    echo "# CLUSTER_ID: ${CLUSTER_ID}"
}

get-invs() {
    get-infra
    echo "# inventry for all hosts"
    #curl --silent --fail ${API_URL}${INFRA_HREF}/hosts | jq -r '.[] | select(.requested_hostname=="${NODE0_NAME}") | .inventory' | jq .
    curl --silent --fail ${API_URL}${INFRA_HREF}/hosts | jq .

    echo "# assisted events:"
    get-clusterid
    curl --silent --fail "${API_URL}/events?cluster_id=$CLUSTER_ID" | jq '.'
}

get-events() {
    get-infra
    echo "# inventry for all hosts"
    #curl --silent --fail ${API_URL}${INFRA_HREF}/hosts | jq -r '.[] | select(.requested_hostname=="${NODE0_NAME}") | .inventory' | jq .
    curl --silent --fail ${API_URL}${INFRA_HREF}/hosts | jq .

    echo "# assisted events:"
    get-clusterid
    curl --silent --fail "${API_URL}/events?cluster_id=$CLUSTER_ID" | jq '.'
}

get-hosts() {
    get-infra
    echo "# inventry for all hosts"
    #curl --silent --fail ${API_URL}${INFRA_HREF}/hosts | jq -r '.[] | select(.requested_hostname=="${NODE0_NAME}") | .inventory' | jq .
    curl --silent --fail ${API_URL}${INFRA_HREF}/hosts | jq .
    curl --silent --fail ${API_URL}${INFRA_HREF}/hosts | jq '.[] | select(.requested_hostname|test("^master*")) | .id'
}

