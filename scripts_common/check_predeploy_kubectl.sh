# This script checks the IBM Cloud Kubernetes Service cluster is ready, has a namespace configured with access to the private
# image registry (using an IBM Cloud API Key). It also configures Helm Tiller service to later perform a deploy with Helm.

# Input env variables (can be received via a pipeline environment properties.file.
echo "IMAGE_NAME=${IMAGE_NAME}"
echo "IMAGE_TAG=${IMAGE_TAG}"
echo "REGISTRY_URL=${REGISTRY_URL}"
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}"

# View build properties
if [ -f build.properties ]; then
  echo "build.properties:"
  cat build.properties
else
  echo "build.properties : not found"
fi

# Input env variables from pipeline job
echo "PIPELINE_KUBERNETES_CLUSTER_NAME=${PIPELINE_KUBERNETES_CLUSTER_NAME}"
echo "CLUSTER_NAMESPACE=${CLUSTER_NAMESPACE}"

echo "=========================================================="
echo "CHECKING DEPLOYMENT.YML manifest"
#Update deployment.yml with image name
if [ -z "${DEPLOYMENT_FILE}" ]; then DEPLOYMENT_FILE=deployment.yml ; fi
if [ ! -f ${DEPLOYMENT_FILE} ]; then
    echo -e "${red}Kubernetes deployment file '${DEPLOYMENT_FILE}' not found${no_color}"
    exit 1
fi

#Check cluster availability
echo "=========================================================="
echo "CHECKING CLUSTER readiness and namespace existence"
IP_ADDR=$( bx cs workers ${PIPELINE_KUBERNETES_CLUSTER_NAME} | grep normal | awk '{ print $2 }' )
if [ -z "${IP_ADDR}" ]; then
  echo -e "${PIPELINE_KUBERNETES_CLUSTER_NAME} not created or workers not ready"
  exit 1
fi
echo "Configuring cluster namespace"
if kubectl get namespace ${CLUSTER_NAMESPACE}; then
  echo -e "Namespace ${CLUSTER_NAMESPACE} found."
else
  kubectl create namespace ${CLUSTER_NAMESPACE}
  echo -e "Namespace ${CLUSTER_NAMESPACE} created."
fi

# Grant access to private image registry from namespace $CLUSTER_NAMESPACE
echo "=========================================================="
echo -e "CONFIGURING ACCESS to private image registry from namespace ${CLUSTER_NAMESPACE}"
IMAGE_PULL_SECRET_NAME="ibmcloud-toolchain-${PIPELINE_TOOLCHAIN_ID}-${REGISTRY_URL}"

echo -e "Checking for presence of ${IMAGE_PULL_SECRET_NAME} imagePullSecret for this toolchain"
if ! kubectl get secret ${IMAGE_PULL_SECRET_NAME} --namespace ${CLUSTER_NAMESPACE}; then
  echo -e "${IMAGE_PULL_SECRET_NAME} not found in ${CLUSTER_NAMESPACE}, creating it"
  # for Container Registry, docker username is 'token' and email does not matter
  kubectl --namespace ${CLUSTER_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=${REGISTRY_URL} --docker-password=${PIPELINE_BLUEMIX_API_KEY} --docker-username=iamapikey --docker-email=a@b.com
else
  echo -e "Namespace ${CLUSTER_NAMESPACE} already has an imagePullSecret for this toolchain."
fi
SERVICE_ACCOUNT=$(kubectl get serviceaccount default  -o json --namespace ${CLUSTER_NAMESPACE} )
if ! echo ${SERVICE_ACCOUNT} | jq -e '. | has("imagePullSecrets")' > /dev/null ; then
  kubectl patch --namespace ${CLUSTER_NAMESPACE} serviceaccount/default -p '{"imagePullSecrets":[{"name":"'"${IMAGE_PULL_SECRET_NAME}"'"}]}'
else
  if echo ${SERVICE_ACCOUNT} | jq -e '.imagePullSecrets[] | select(.name=="'"${IMAGE_PULL_SECRET_NAME}"'")' > /dev/null ; then
    echo -e "Pull secret already found in default serviceAccount"
  else
    echo "Inserting toolchain pull secret into default serviceAccount"
    kubectl patch --namespace ${CLUSTER_NAMESPACE} serviceaccount/default --type='json' -p='[{"op":"add","path":"/imagePullSecrets/-","value":{"name": "'"${IMAGE_PULL_SECRET_NAME}"'"}}]'
  fi
fi
echo "default serviceAccount:"
kubectl get serviceaccount default --namespace ${CLUSTER_NAMESPACE} -o yaml
echo -e "Namespace ${CLUSTER_NAMESPACE} authorizing with private image registry using patched default serviceAccount"
