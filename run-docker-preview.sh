#!/bin/bash
#
# Description:
#   This is used by gitlab ci to start and manage docker instances for
#   hosting previews of doc sites.
# test
set -e 

DOCKER_IMAGE="httpd:2.4"
CONTAINER_NAME=local-test
if [[ ! -z "${WORKSPACE}" ]];then
    CONTAINER_NAME=$(basename ${WORKSPACE})
fi

PREVIEW_DIR=/opt/opendocs-previews/${CONTAINER_NAME}

PREVIEW_PORT=""
CONTAINER_ID=""

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

rm -rf ${PREVIEW_DIR}
mkdir -p ${PREVIEW_DIR}
cp -r ${WORKSPACE}/build/public/* ${PREVIEW_DIR}

docker run -d \
  --restart unless-stopped \
  -v $(pwd):/usr/local/apache2/htdocs/ \
  -p 8081:80 \
  --name "${CONTAINER_NAME}" \
  ${DOCKER_IMAGE}
if [[ $? -ne 0 ]];then
  exit 1
fi

for ((x=0;x<20;x++)); do
  echo "[INFO] Checking for web server available message ..."
  sleep 15
  # Check if the container is running.
  CONTAINER_ID=`docker container ls -f name="^${CONTAINER_NAME}$" -q`
  if [[ -z "${CONTAINER_ID}" ]];then
    echo "[ERROR] Didn't find running container named [${CONTAINER_NAME}]."
    CONTAINER_ID=`docker container ls -a -f name="^${CONTAINER_NAME}$" -q`
    if [[ -z "${CONTAINER_ID}" ]];then
      echo "[ERROR] Didn't find stopped container named [${CONTAINER_NAME}]."
    else
      echo "[ERROR] Printing docker logs of container that failed to start."
      echo "=========================================================="
      docker logs ${CONTAINER_ID}
      echo "=========================================================="
    fi
    exit 1
  else
    exit 0
  fi
#   else
#     if docker logs ${CONTAINER_ID} 2>&1  | grep "Web Server is available" > /dev/null;then
#       echo "=========================================================="
#       docker logs ${CONTAINER_ID} | sed -e "s|http://localhost:1313/|http://$(hostname -f):${PREVIEW_PORT}|g"
#       echo "=========================================================="
#       exit 0
#     fi
  fi
done
# should never get to this point
exit 1
