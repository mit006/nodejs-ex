echo "REGISTRY_URL=${REGISTRY_URL}"
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}"
echo "IMAGE_NAME=${IMAGE_NAME}"
echo "ARCHIVE_DIR=${ARCHIVE_DIR}"
echo "DOCKER_ROOT=${DOCKER_ROOT}"
echo "DOCKER_FILE=${DOCKER_FILE}"


# View build properties
if [ -f build.properties ]; then
  echo "build.properties:"
  cat build.properties
else
  echo "build.properties : not found"
fi

echo "=========================================================="
echo "Checking for Dockerfile at the repository root"
if [ -z "${DOCKER_ROOT}" ]; then DOCKER_ROOT=. ; fi
if [ -z "${DOCKER_FILE}" ]; then DOCKER_FILE=Dockerfile ; fi
if [ -f ${DOCKER_ROOT}/${DOCKER_FILE} ]; then
echo -e "Dockerfile found at: ${DOCKER_FILE}"
else
    echo "Dockerfile not found at: ${DOCKER_FILE}"
    exit 1
fi
echo "Linting Dockerfile"
npm install -g dockerlint
dockerlint -f ${DOCKER_ROOT}/${DOCKER_FILE}

echo "=========================================================="
echo "Checking registry current plan and quota"
bx cr plan
bx cr quota
echo "If needed, discard older images using: bx cr image-rm"
echo "Checking registry namespace: ${REGISTRY_NAMESPACE}"
NS=$( bx cr namespaces | grep ${REGISTRY_NAMESPACE} ||: )
if [ -z "${NS}" ]; then
    echo "Registry namespace ${REGISTRY_NAMESPACE} not found, creating it."
    bx cr namespace-add ${REGISTRY_NAMESPACE}
    echo "Registry namespace ${REGISTRY_NAMESPACE} created."
else
    echo "Registry namespace ${REGISTRY_NAMESPACE} found."
fi
echo -e "Existing images in registry"
bx cr images --restrict ${REGISTRY_NAMESPACE}
