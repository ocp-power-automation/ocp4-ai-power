
# ! /usr/bin/bash
#
# This script is to deploy assisted service on local power system, and it can be used to test any version of OCP release.
#
# Environment variables used in script:
#   SERVER_IP -- the hosts' IP where this script will run on
SERVER_IP=${SERVER_IP:-"<host_ip>"}

# check postgrs db:
#  dnf module -y install postgresql:16
#  psql -c "select usename from pg_user;" --host=127.0.0.1 --username=admin --password -d installer
##### OCP GA release #####
# OCP_RELEASE="ocp"
# OCP_VERSION="latest-4.16"
##### OCP PRE release #####"
OCP_RELEASE="ocp-dev-preview"
OCP_VERSION="candidate-4.17"
##### OCP nightly build version #####
# OCP_RELEASE="nightly"
# OCP_VERSION="4.17.0"

PULL_SECRECT="-a $HOME/.openshift/pull-secret"
INSTALLER="./openshift-install"

CPU_ARCH=$(uname -m)

download_installer() {
  if [ ! -f "${INSTALLER}" ]; then
      echo "Download installer"
      wget https://mirror.openshift.com/pub/openshift-v4/${CPU_ARCH}/clients/${OCP_RELEASE}/${OCP_VERSION}/openshift-install-linux.tar.gz
      tar xzvf openshift-install-linux.tar.gz
      rm -f openshift-install-linux.tar.gz README.md
  fi
}

get_ocp_release() {
  echo "Download the OCP:${OCP_VERSION} README.txt"
  wget https://mirror.openshift.com/pub/openshift-v4/${CPU_ARCH}/clients/${OCP_RELEASE}/${OCP_VERSION}/release.txt
  export RELEASE_IMAGE_DIGEST=$(cat release.txt | grep "Pull From:" | awk -F" " '{print $3}')
  echo "Extract openshift-install from OCP release: ${RELEASE_IMAGE_DIGEST}"
  oc adm release extract ${PULL_SECRECT} --command openshift-install ${RELEASE_IMAGE_DIGEST}
}

get_ocp_nightly() {
  echo "get nightly build OCP image URL for $OCP_VERSION"
  # quay.io/openshift/ci:<namespace>_<name>_<tag>
  # registry.ci.openshift.org/ocp-ppc64le/release-ppc64le:4.16.0-0.nightly-ppc64le-2024-08-12-121050
  export RELEASE_IMAGE_DIGEST=$(curl -s https://ppc64le.ocp.releases.ci.openshift.org/api/v1/releasestream/${OCP_VERSION}-0.nightly-ppc64le/latest | jq -r .pullSpec)
  echo "Extract openshift-install from OCP release: ${RELEASE_IMAGE_DIGEST}"
  oc adm release extract ${PULL_SECRECT} --command openshift-install ${RELEASE_IMAGE_DIGEST}

}

image_for() {
  podman run --quiet --rm --net=none "${RELEASE_IMAGE_DIGEST}" image "${1}"
}

setup_env() {
  ${INSTALLER} version
  export RELEASE_IMAGE_DIGEST=$(${INSTALLER} version | grep "release image" | awk -F" " '{print $3}')
  export RELEASE_IMAGE_VERSION=$(${INSTALLER} version | grep "openshift-install" | awk -F" " '{print $2}')
  export COREOS_ISO_URL=$(${INSTALLER} coreos print-stream-json | jq -r .architectures.${CPU_ARCH}.artifacts.metal.formats.iso.disk.location)
  export COREOS_ISO_VERSION=$(${INSTALLER} coreos print-stream-json | jq -r .architectures.${CPU_ARCH}.artifacts.metal.release)
  #export OCP_VERSION=$(${INSTALLER} coreos print-stream-json | jq -r .stream | awk -F "-" '{print $2}')
  export OCP_VERSION=$(${INSTALLER} version | grep "openshift-install" | awk -F" " '{print $2}')
  echo "OCP_VERSION: ${OCP_VERSION}"
  export RELEASE_CPU=$(${INSTALLER} version | grep "release architecture" | awk -F" " '{print $3}')
  echo "RELEASE_CPU: ${RELEASE_CPU}"
  # Images for assisted service installer
  export AGENT_DOCKER_IMAGE=$(image_for agent-installer-node-agent) # quay.io/cszhang/assisted-installer-agent:ppc64le
  export INSTALLER_IMAGE=$(image_for agent-installer-orchestrator)  # quay.io/cszhang/assisted-installer:ppc64le
  export CONTROLLER_IMAGE=$(image_for agent-installer-csr-approver) # quay.io/cszhang/assisted-installer-controller:ppc64le
  # Images for Assisted service
  #export API_SERVICE=quay.io/cszhang/assisted-service:ppc64le-test
  export API_SERVICE=$(image_for agent-installer-api-server)      # quay.io/cszhang/assisted-service:ppc64le
  if [ ${CPU_ARCH} == "ppc64le" ]; then
    export IMAGE_SERVICE=quay.io/cszhang/assisted-image-service:ppc64le
    export UI_SERVICE=quay.io/cszhang/assisted-installer-ui:ppc64le
  else # for x86_64
    export IMAGE_SERVICE=quay.io/edge-infrastructure/assisted-image-service:latest
    export UI_SERVICE=quay.io/edge-infrastructure/assisted-installer-ui:latest
  fi

  cat > ./deploy_release_images.json << EOF
[
    {
        "openshift_version": "${OCP_VERSION}",
        "cpu_architecture": "${CPU_ARCH}",
        "cpu_architectures": ["${CPU_ARCH}"],
        "url": "${RELEASE_IMAGE_DIGEST}",
        "version": "${RELEASE_IMAGE_VERSION}",
        "default": true
    }
]
EOF

  cat > ./deploy_os_images.json << EOF
[
    {
        "openshift_version": "${OCP_VERSION}",
        "cpu_architecture": "${CPU_ARCH}",
        "url": "${COREOS_ISO_URL}",
        "version": "${COREOS_ISO_VERSION}"
    }
]
EOF


  export DEFAULT_RELEASE_IMAGES=$(tr -d '\n\t ' < ./deploy_release_images.json) # Or $(cat ./deploy_release_images.json | jq -c .)
  export DEFAULT_OS_IMAGES=$(tr -d '\n\t ' < ./deploy_os_images.json)
  export SERVER_IP=${SERVER_IP:-9.114.97.105}
  # export TAG=${CPU_ARCH}
  # ENV_FILE=deploy_assisted_service.env
  # cat ${ENV_FILE}.template | envsubst > ${ENV_FILE}
  # source ${ENV_FILE}


# startup can be slower when the VM is not connected to the internet
#sudo firewall-cmd --permanent --add-port={8090/tcp,8080/tcp,8888/tcp}
#sudo firewall-cmd --reload

# securityContext:
#     runAsUser: 26
# equs to [--user postgres], postgres UID is 26 for CentOS/RHEL

    cat > pod-persistent.yml << EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: assisted-installer
  name: assisted-installer
spec:
  containers:
  - name: db
    image: ${API_SERVICE}
    securityContext:
      runAsUser: 26
    command: ["/bin/bash"]
    args: ["start_db.sh"]
    envFrom:
      - configMapRef:
          name: config
  - name: ui
    image: ${UI_SERVICE}
    ports:
      - hostPort: 8080
    envFrom:
      - configMapRef:
          name: config
  - name: image-service
    image: ${IMAGE_SERVICE}
    ports:
      - hostPort: 8888
    envFrom:
      - configMapRef:
          name: config
  - name: service
    image: ${API_SERVICE}
    ports:
      - hostPort: 8090
    envFrom:
      - configMapRef:
          name: config
  restartPolicy: Never
EOF



    cat > pod-configmap.yml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: config
data:
  ASSISTED_SERVICE_HOST: ${SERVER_IP}:8090
  ASSISTED_SERVICE_SCHEME: http
  AUTH_TYPE: none
  DB_HOST: 127.0.0.1
  DB_NAME: installer
  DB_PASS: admin
  DB_PORT: "5432"
  DB_USER: admin
  DEPLOY_TARGET: onprem
  DEPLOYMENT_TYPE: "Podman"
  DISK_ENCRYPTION_SUPPORT: "true"
  DUMMY_IGNITION: "false"
  ENABLE_SINGLE_NODE_DNSMASQ: "true"
  HW_VALIDATOR_REQUIREMENTS: '[{"version":"default","master":{"cpu_cores":4,"ram_mib":16384,"disk_size_gb":100,"installation_disk_speed_threshold_ms":10,"network_latency_threshold_ms":100,"packet_loss_percentage":0},"worker":{"cpu_cores":2,"ram_mib":8192,"disk_size_gb":100,"installation_disk_speed_threshold_ms":10,"network_latency_threshold_ms":1000,"packet_loss_percentage":10},"sno":{"cpu_cores":8,"ram_mib":16384,"disk_size_gb":100,"installation_disk_speed_threshold_ms":10}}]'
  IMAGE_SERVICE_BASE_URL: http://${SERVER_IP}:8888
  IPV6_SUPPORT: "true"
  ISO_IMAGE_TYPE: "full-iso"
  LISTEN_PORT: "8888"
  NTP_DEFAULT_SERVER: ""
  OS_IMAGES: '${DEFAULT_OS_IMAGES}'
  POSTGRESQL_DATABASE: installer
  POSTGRESQL_PASSWORD: admin
  POSTGRESQL_USER: admin
  PUBLIC_CONTAINER_REGISTRIES: 'quay.io'
  RELEASE_IMAGES: '${DEFAULT_RELEASE_IMAGES}'
  SERVICE_BASE_URL: http://${SERVER_IP}:8090
  STORAGE: filesystem
  ENABLE_UPGRADE_AGENT: "true"
  AGENT_DOCKER_IMAGE: "${AGENT_DOCKER_IMAGE}"
  CONTROLLER_IMAGE: "${CONTROLLER_IMAGE}"
  INSTALLER_IMAGE: "${INSTALLER_IMAGE}"
EOF
}

deploy() {
  echo "Download openshift-install"
  download_installer # download installer from mirror site
  #get_ocp_release    # download installer from release readme
  #get_ocp_nightly    # download installer from nightly build
  echo "Setup deploy configure files"
  setup_env

  echo "Start assisted service"
  podman play kube --configmap pod-configmap.yml pod-persistent.yml
}

destory() {
  echo "Tear down assisted service"
  podman play kube --down --configmap pod-configmap.yml pod-persistent.yml
  rm -f ${INSTALLER} release.txt deploy_* pod-*
}

##############################################
if [[ "${SERVER_IP}" == "<host_ip>" ]]; then
  echo "SERVER_IP need to be defined before run this script"
  exit 1
fi

if [[ $# -eq 1 && "$1" != "deploy" ]]; then
  destory
else
  deploy
  source ./ai-utils.sh
fi
