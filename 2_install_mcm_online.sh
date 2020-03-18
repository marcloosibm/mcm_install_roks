# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Install Script for MCM on IBM ROKS Cloud
#
# V1.0 
#
# ©2020 nikh@ch.ibm.com
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[1;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color





# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Default Values
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
export MCM_USER=admin
export MCM_PWD=passw0rd
export TEMP_PATH=$TMPDIR
export STORAGE_CLASS=ibmc-block-gold

export MASTER_HOST=0.0.0.0
export PROXY_HOST=0.0.0.0
export MANAGEMENT_HOST=0.0.0.0

export INCEPTION_VERSION=3.2.3


# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Do Not Edit Below
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "  "
echo " ${GREEN}MCM Install for OpensHift 4.2 on IBM Cloud${NC}"
echo "  "
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "  "
echo "  "
echo "  "



# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# GET PARAMETERS
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Input Parameters${NC}"
echo "---------------------------------------------------------------------------------------------------------------------------"


while getopts "t:d:h:p:s:" opt
do
   case "$opt" in
      t ) INPUT_TOKEN="$OPTARG" ;;
      d ) INPUT_PATH="$OPTARG" ;;
      h ) INPUT_CLUSTER_NAME="$OPTARG" ;;
      p ) INPUT_PWD="$OPTARG" ;;
      s ) INPUT_SC="$OPTARG" ;;
   esac
done



if [[ $INPUT_TOKEN == "" ]];
then
echo "    ${RED}ERROR${NC}: Please provide the Registry Token"
echo "    USAGE: ./2_install_mcm_online.sh -t <REGISTRY_TOKEN> [-h <CLUSTER_NAME>] [-p <MCM_PASSWORD>] [-d <TEMP_DIRECTORY>] [-s <STORAGE_CLASS>]"
exit 1
else
  echo "    ${GREEN}Token OK:${NC}                           '$INPUT_TOKEN'"
  ENTITLED_REGISTRY_KEY=$INPUT_TOKEN
fi



if [[ ($INPUT_CLUSTER_NAME == "") ]];
then
  echo "    ${ORANGE}No Cluster Name provided${NC}            ${GREEN}will be determined from Cluster${NC}"
else
  echo "    ${GREEN}Cluster OK:${NC}                           '$INPUT_CLUSTER_NAME'"
  CLUSTER_NAME=$INPUT_CLUSTER_NAME
fi



if [[ $INPUT_PWD == "" ]];          
then
  echo "    ${ORANGE}No Password provided, using${NC}         '$MCM_PWD'"
else
  echo "    ${GREEN}Password OK:${NC}                        '$INPUT_PWD'"
  MCM_PWD=$INPUT_PWD
fi



if [[ $INPUT_PATH == "" ]];
then
  echo "    ${ORANGE}No Path provided, using${NC}             '$TEMP_PATH'"
else
  echo "    ${GREEN}Path OK:${NC}                            '$INPUT_PATH'"
  TEMP_PATH=$INPUT_PATH
fi



if [[ $INPUT_SC == "" ]];
then
  echo "    ${ORANGE}No Storage Class provided, using${NC}    '$STORAGE_CLASS'"
else
  echo "    ${GREEN}Storage Class OK:${NC}                   '$INPUT_SC'"
  STORAGE_CLASS=$INPUT_SC
fi



if [[ ($INPUT_CLUSTER_NAME == "") ]];
then
  echo "  "
  echo "---------------------------------------------------------------------------------------------------------------------------"
  echo " ${ORANGE}Cluster Name not set${NC}"
  echo " ${BLUE}  Determining Cluster FQN${NC}"
  echo "---------------------------------------------------------------------------------------------------------------------------"
    CLUSTER_ROUTE=$(kubectl get routes router | tail -n 1 2>&1 ) 
    if [[ $CLUSTER_ROUTE =~ "router-default" ]];
    then
      CLUSTER_FQDN=$( echo $CLUSTER_ROUTE | awk '{print $2}')
      if [[ $(uname) =~ "Darwin" ]];
      then
          CLUSTER_NAME=$(echo $CLUSTER_FQDN | sed -e "s/router-default.//")
      else
          CLUSTER_NAME=$(echo $CLUSTER_FQDN | sed "s/router-default.//")
      fi
      echo "    ${GREEN}Cluster FQDN:${NC}                        '$CLUSTER_NAME'"

    else
      echo "    ${RED}Cannot determine Route${NC}"
      echo "    ${ORANGE}Check your Kubernetes Configuration${NC}"
      echo "    ${RED}Aborting${NC}"
      exit 1
    fi
fi


if [[ ($MASTER_HOST == "0.0.0.0") ]];
then
  echo "  "
  echo "---------------------------------------------------------------------------------------------------------------------------"
  echo " ${ORANGE}Installation Nodes not set${NC}"
  echo " ${BLUE}  Determining Cluster Node IPs${NC}"
  echo "---------------------------------------------------------------------------------------------------------------------------"
    CLUSTERS=$(kubectl get nodes 2>&1 ) 

    if [[ $CLUSTERS =~ "NAME" ]];
    then
      CLUSTER_W1=$( kubectl get nodes | sed -n 2p | awk '{print $1}' 2>&1 ) 
      CLUSTER_W2=$( kubectl get nodes | sed -n 3p | awk '{print $1}' 2>&1 ) 

      export MASTER_HOST=$CLUSTER_W1
      export PROXY_HOST=$CLUSTER_W1
      export MANAGEMENT_HOST=$CLUSTER_W2

      echo "    ${GREEN}Setting Master to: ${NC}                 '$MASTER_HOST'"
      echo "    ${GREEN}Setting Proxy to: ${NC}                  '$PROXY_HOST'"
      echo "    ${GREEN}Setting Management to: ${NC}             '$MANAGEMENT_HOST'"
    else
      echo "    ${RED}Cannot determine Cluster Nodes${NC}"
      echo "    ${ORANGE}Check your Kubernetes Configuration${NC}"
      echo "    ${RED}Aborting${NC}"
      exit 1
    fi
fi
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"










# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# PRE-INSTALL CHECKS
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "  "
echo "  "
echo "  "
echo "  "
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Pre-Install Checks${NC}"
echo "---------------------------------------------------------------------------------------------------------------------------"


echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "    Check if ${BLUE}OpenShift${NC} is reachable at               $CONSOLE_URL"

PING_RESOLVE=$(ping -c 1 $CONSOLE_URL 2>&1)


if [[ $PING_RESOLVE =~ "cannot resolve" ]];
then
  echo "    ${RED}ERROR${NC}: Cluster '$CLUSTER_NAME' is not reachable"
  exit 1
else 
  echo "    ${GREEN}OK${NC}"
fi



echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "    Check if OpenShift ${BLUE}KUBECONTEXT${NC} is set for        $CLUSTER_NAME"

KUBECTX_RESOLVE=$(kubectl get routes --all-namespaces 2>&1)


if [[ $KUBECTX_RESOLVE =~ $CLUSTER_NAME ]];
then
  echo "    ${GREEN}OK${NC}"
else 
  echo "    ${RED}ERROR${NC}: Please log into  '$CLUSTER_NAME' via the OpenShift web console"
  exit 1
fi



echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "    Check if ${BLUE}Storage Class${NC} exists on                 $CLUSTER_NAME"

SC_RESOLVE=$(oc get sc 2>&1)


if [[ $SC_RESOLVE =~ $STORAGE_CLASS ]];
then
  echo "    ${GREEN}OK${NC}"
else 
  echo "    ${RED}ERROR${NC}: Storage Class $STORAGE_CLASS does not exist on Cluster '$CLUSTER_NAME'. Aborting."
  exit 1
fi



echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "    Check if ${BLUE}Docker Registry Credentials${NC} work ($ENTITLED_REGISTRY_KEY)"
echo "    This might take some time"

export ENTITLED_REGISTRY=cp.icr.io
export ENTITLED_REGISTRY_USER=ekey

DOCKER_LOGIN=$(docker login "$ENTITLED_REGISTRY" -u "$ENTITLED_REGISTRY_USER" -p "$ENTITLED_REGISTRY_KEY" 2>&1)

DOCKER_PULL=$(docker pull cp.icr.io/cp/icp-foundation/mcm-inception:$INCEPTION_VERSION 2>&1)
#echo $DOCKER_PULL

if [[ $DOCKER_PULL =~ "pull access denied" ]];
then
echo "${RED}ERROR${NC}: Not entitled for Registry or not reachable"
exit 1
else
  echo "    ${GREEN}OK${NC}"
fi

echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"




# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Define some Stuff
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
export INSTALL_PATH=$TEMP_PATH/mcm-$CLUSTER_NAME

export MASTER_COMPONENTS=$MASTER_HOST  #.$CLUSTER_NAME
export PROXY_COMPONENTS=$PROXY_HOST  #.$CLUSTER_NAME
export MANAGEMENT_COMPONENTS=$MANAGEMENT_HOST  #.$CLUSTER_NAME






echo "  "
echo "  "
echo "  "
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Your configuration${NC}"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}CLUSTER :${NC}               $CLUSTER_NAME"
echo "    ${GREEN}REGISTRY TOKEN:${NC}         $ENTITLED_REGISTRY_KEY"
echo "    ---------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}MCM User Name:${NC}          $MCM_USER"
echo "    ${GREEN}MCM User Password:${NC}      ********"
echo "    ---------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}STORAGE CLASS:${NC}          $STORAGE_CLASS"
echo "    ---------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}MASTER COMPONENTS:${NC}      $MASTER_COMPONENTS"
echo "    ${GREEN}PROXY COMPONENTS:${NC}       $PROXY_COMPONENTS"
echo "    ${GREEN}MANAGEMENT COMPONENTS:${NC}  $MANAGEMENT_COMPONENTS"
echo "    ---------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}INSTALL PATH:${NC}           $INSTALL_PATH"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "  "
echo "  "
echo "  "
echo "  "



# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# PREREQUISITES
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Getting MCM Inception Container${NC} - ${ORANGE}This may take some time${NC}"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"

docker login "$ENTITLED_REGISTRY" -u "$ENTITLED_REGISTRY_USER" -p "$ENTITLED_REGISTRY_KEY"

DOCKER_PULL=$(docker pull cp.icr.io/cp/icp-foundation/mcm-inception:$INCEPTION_VERSION 2>&1)
#echo $DOCKER_PULL

if [[ $DOCKER_PULL =~ "pull access denied" ]];
then
  echo "${RED}ERROR${NC}: Not entitled for Registry or not reachable"
  exit 1
fi

echo "  "
echo "  "
echo "  "
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}MCM will be installed in Cluster ${ORANGE}'$CLUSTER_NAME'${NC}"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"

echo "Patching Route"
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}' 2>&1
echo "Patching Route Done"

echo "---------------------------------------------------------------------------------------------------------------------------"
echo " Create Secret for Registry"
#docker login "$ENTITLED_REGISTRY" -u "$ENTITLED_REGISTRY_USER" -p "$ENTITLED_REGISTRY_KEY"
oc create secret docker-registry entitled-registry --docker-server=cp.icr.io --docker-username=$ENTITLED_REGISTRY_USER --docker-password=$ENTITLED_REGISTRY_KEY --docker-email=nikh@ch.ibm.com

echo "---------------------------------------------------------------------------------------------------------------------------"
echo " Create Config Files"
sudo rm -r $INSTALL_PATH 
mkdir -p $INSTALL_PATH 
cd $INSTALL_PATH

docker run --rm -v $(pwd):/data:z -e LICENSE=accept --security-opt label:disable cp.icr.io/cp/icp-foundation/mcm-inception:$INCEPTION_VERSION cp -r cluster /data

echo "---------------------------------------------------------------------------------------------------------------------------"
echo " Copy kubeconfig"
oc config view > $INSTALL_PATH/cluster/kubeconfig

echo "  "
echo "  "
echo "  "
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Adapt cluster config file${NC}"
echo ""

cd $INSTALL_PATH

# Copy vanilla config
cp cluster/config.yaml cluster/config.yaml.vanilla


# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Adapt Config FIle
# ---------------------------------------------------------------------------------------------------------------------------------------------------"

if [[ $(uname) =~ "Darwin" ]];

then
    echo " ${GREEN}Adapt Config File for OSX${NC}"
    sed -i'.bak' -e "s/<your-openshift-dedicated-node-to-deploy-master-components>/$MASTER_COMPONENTS/" cluster/config.yaml
    sed -i'.bak' -e "s/<your-openshift-dedicated-node-to-deploy-proxy-components>/$PROXY_COMPONENTS/" cluster/config.yaml
    sed -i'.bak' -e "s/<your-openshift-dedicated-node-to-deploy-management-components>/$MANAGEMENT_COMPONENTS/" cluster/config.yaml

    sed -i'.bak' -e  "s/<storage class available in OpenShift>/$STORAGE_CLASS/" cluster/config.yaml

    sed -i'.bak' -e "s/notary: disabled/notary: enabled/" cluster/config.yaml
    sed -i'.bak' -e "s/cis-controller: disabled/notary: enabled/" cluster/config.yaml
    sed -i'.bak' -e "s/mutation-advisor: disabled/notary: enabled/" cluster/config.yaml

else
    echo " ${GREEN}Adapt Adapt Config File for Linux${NC}"
    sed -i "s/<your-openshift-dedicated-node-to-deploy-master-components>/$MASTER_COMPONENTS/" cluster/config.yaml
    sed -i "s/<your-openshift-dedicated-node-to-deploy-proxy-components>/$PROXY_COMPONENTS/" cluster/config.yaml
    sed -i "s/<your-openshift-dedicated-node-to-deploy-management-components>/$MANAGEMENT_COMPONENTS/" cluster/config.yaml

    sed -i "s/<storage class available in OpenShift>/$STORAGE_CLASS/" cluster/config.yaml

    sed -i "s/notary: disabled/notary: enabled/" cluster/config.yaml
    sed -i "s/cis-controller: disabled/notary: enabled/" cluster/config.yaml
    sed -i "s/mutation-advisor: disabled/notary: enabled/" cluster/config.yaml

fi


echo "image_repo: cp.icr.io/cp/icp-foundation"  >> cluster/config.yaml
echo "private_registry_enabled: true"  >> cluster/config.yaml
echo "docker_username: ekey"  >> cluster/config.yaml
echo "docker_password: $ENTITLED_REGISTRY_KEY"  >> cluster/config.yaml


#sed -i "s/monitoring: enabled/monitoring: disabled/" cluster/config.yaml

echo "default_admin_password: $MCM_PWD" >> cluster/config.yaml
echo "password_rules:" >> cluster/config.yaml
echo "- '(.*)'" >> cluster/config.yaml



echo "  "
echo "  "
echo "  "
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo " ${GREEN}Current config file for installation${NC}"
echo " ${GREEN}Please Check if it looks OK${NC}"
echo " ${ORANGE}vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv${NC}"
echo "  "
cat cluster/config.yaml
echo "  "
echo " ${ORANGE}^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^${NC}"
echo " ${GREEN}Current config file for installation${NC}"
echo " ${GREEN}Please Check if it looks OK${NC}"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "  "
echo "  "
echo "  "

echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo " ${ORANGE}Do you want to install MCM into Cluster '$CLUSTER_NAME' with the above configuration?${NC}"
echo ""
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"

read -p "Install? [y,N]" DO_COMM
if [[ $DO_COMM == "y" ||  $DO_COMM == "Y" ]]; then
  cd cluster 
  docker run -t --net=host -e LICENSE=accept -v $(pwd):/installer/cluster:z -v /var/run:/var/run:z -v /etc/docker:/etc/docker:z --security-opt label:disable cp.icr.io/cp/icp-foundation/mcm-inception:$INCEPTION_VERSION install-with-openshift
else
  echo "${RED}Installation Aborted${NC}"
fi

echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo " DONE"
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"
