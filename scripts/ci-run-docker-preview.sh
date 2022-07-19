#!/bin/bash
#
# Description:
#   This is used by Jenkins to start previews of doc sites.
set -e 

DOCKER_IMAGE="httpd:2.4"

CONTAINER_NAME=localtest
WORKSPACE=${WORKSPACE}
NODE_NAME="${NODE_NAME}"
PREVIEW_DIR=/opt/opendocs-previews/${CONTAINER_NAME}
PREVIEW_PORT=""
CONTAINER_ID=""


if [[ ! -z "${WORKSPACE}" ]];then
    CONTAINER_NAME=$(basename ${WORKSPACE})
fi
echo "[INFO] CONTAINER_NAME set to [${CONTAINER_NAME}]."

# Find and reuse port already used for the pipeline.
PREVIEW_PORT=`docker ps | grep " ${CONTAINER_NAME}$" | sed -e "s|.*:\(8.*\)->.*|\1|g"`

# Makes sure PREVIEW_PORT is set to an integer.
if [[ "$PREVIEW_PORT" =~ ^[-+]?[0-9]+$ ]];then
  echo "[INFO] Reusing port [${PREVIEW_PORT}]!"
else
  # This for loop finds the next available port.
  echo "[INFO] Find available port between 8081 and 8181!"
  PREVIEW_PORT=""
  for ((i=8081;i<=8181;i++)); do
      if netstat -tuln | grep LISTEN | grep ":${i} " > /dev/null;then
          echo "[INFO] Port [${i}] in use."
      else
          echo "[INFO] Port [${i}] is free."
          PREVIEW_PORT=${i}
          break
      fi
  done
  if [[ -z "${PREVIEW_PORT}" ]];then
    echo "[ERROR] Could not find a free port to use."
    exit 1
  fi
fi

# Check if container running using the expected name. If yes then stop it.
CONTAINER_ID=`docker container ls -f name="^${CONTAINER_NAME}$" -q`
if [[ ! -z "${CONTAINER_ID}" ]];then
    echo "[INFO] Stopping container [${CONTAINER_ID}]!"
    docker update --restart no ${CONTAINER_ID}
    docker stop ${CONTAINER_ID}
fi
# Delete stopped containers. 
CONTAINER_ID=`docker container ls -a -f name="^${CONTAINER_NAME}$" -q`
if [[ ! -z "${CONTAINER_ID}" ]];then
    echo "[INFO] Removing stopped container [${CONTAINER_ID}]!"
    docker rm -f ${CONTAINER_ID}
fi
echo "[INFO]"

echo "[INFO] Copying generated static website files:"
echo "[INFO]    from [${WORKSPACE}/build/public/]"
echo "[INFO]      to [${PREVIEW_DIR}]"
rm -rf ${PREVIEW_DIR}
mkdir -p ${PREVIEW_DIR}
cp -r ${WORKSPACE}/build/public/* ${PREVIEW_DIR}
echo "[INFO]"

echo "[INFO] Startibg docker container [${CONTAINER_ID}]!" 
docker run -d \
  --restart unless-stopped \
  -v ${PREVIEW_DIR}:/usr/local/apache2/htdocs/ \
  -p ${PREVIEW_PORT}:80 \
  --name "${CONTAINER_NAME}" \
  ${DOCKER_IMAGE}
if [[ $? -ne 0 ]];then
  exit 1
fi
echo "[INFO]"

echo "[INFO] Makes sure container is up and running ..."
for ((x=0;x<20;x++)); do
  sleep 5
  CONTAINER_ID=`docker container ls -f name="^${CONTAINER_NAME}$" -q`
  if [[ -z "${CONTAINER_ID}" ]];then
    echo "[WARN] Didn't find running container named [${CONTAINER_NAME}]."
    # see if docker instance exist ... if yes then print the logs
    CONTAINER_ID=`docker container ls -a -f name="^${CONTAINER_NAME}$" -q`
    if [[ -z "${CONTAINER_ID}" ]];then
      echo "[ERROR] Didn't find stopped container named [${CONTAINER_NAME}]."
    else
      echo "[ERROR] Printing docker logs of container that failed to start."
      echo "=========================================================="
      docker logs ${CONTAINER_ID}
      echo "=========================================================="
      break
    fi
    exit 1
  fi
done
echo "[INFO]"

# This is just to make sure the humanly readable alias hostname is used in the preview link.
alt_hostname=""
orig_ip=""
if [[ ! -z "${NODE_NAME}" ]];then
  orig_hostname=$(hostname -f)
  orig_short_host=$(hostname -s)
  orig_ip=$(hostname -i)
  alt_hostname=$(echo ${orig_hostname} | sed -e "s|${orig_short_host}|${NODE_NAME}|g")
fi

if [[ "${orig_ip}" == "$(dig ${alt_hostname} +short | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')" ]];then
  echo "[INFO] Preview URL is http://${alt_hostname}:${PREVIEW_PORT}/ !"
  echo "http://${alt_hostname}:${PREVIEW_PORT}/" > _preview_url.txt
else
  echo "[INFO] Preview URL is http://${orig_hostname}:${PREVIEW_PORT}/ !"
  echo "http://${orig_hostname}:${PREVIEW_PORT}/" > _preview_url.txt
fi
exit 0

