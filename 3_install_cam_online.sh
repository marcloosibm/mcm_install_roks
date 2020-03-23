# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Install Script for CAM on IBM ROKS Cloud
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
# Adapt Configuration
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
export CAM_VERSION=4.1.0

# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Default Values
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
export TEMP_PATH=$TMPDIR
export HELM_BIN=helm
export STORAGE_CLASS_BLOCK=ibmc-block-gold
export STORAGE_CLASS_FILE=ibmc-file-gold
export MCM_USER=admin
export MCM_PWD=passw0rd

export OCP_CONSOLE_PREFIX=console-openshift-console




# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Do Not Edit Below
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "  "
echo " ${GREEN}CAM Install for OpensHift 4.2${NC}"
echo "  "
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
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
echo "    USAGE: ./2_install_mcm_online.sh -t <REGISTRY_TOKEN> [-h <CLUSTER_NAME>] [-p <MCM_PASSWORD>] [-d <TEMP_DIRECTORY>] [-s <STORAGE_CLASS_BLOCK>]"
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
  echo "    ${ORANGE}No Storage Class provided, using${NC}    '$STORAGE_CLASS_BLOCK' and '$STORAGE_CLASS_FILE'"
else
  echo "    ${GREEN}Storage Class OK:${NC}                   '$INPUT_SC'"
  STORAGE_CLASS_BLOCK=$INPUT_SC

  if [[ $(uname) =~ "Darwin" ]];
  then
    STORAGE_CLASS_FILE=$(echo $STORAGE_CLASS_BLOCK | sed -e "s/block/file/")
  else
    STORAGE_CLASS_FILE=$(echo $STORAGE_CLASS_BLOCK | sed "s/block/file/")
  fi

fi



if [[ ($INPUT_CLUSTER_NAME == "") ]];
then
  echo "  "
  echo "---------------------------------------------------------------------------------------------------------------------------"
  echo " ${BLUE}Determining Cluster FQN${NC}"
    CLUSTER_ROUTE=$(kubectl get routes console -n openshift-console | tail -n 1 2>&1 ) 
    if [[ $CLUSTER_ROUTE =~ "reencrypt" ]];
    then
      CLUSTER_FQDN=$( echo $CLUSTER_ROUTE | awk '{print $2}')
      if [[ $(uname) =~ "Darwin" ]];
      then
          CLUSTER_NAME=$(echo $CLUSTER_FQDN | sed -e "s/$OCP_CONSOLE_PREFIX.//")
      else
          CLUSTER_NAME=$(echo $CLUSTER_FQDN | sed "s/$OCP_CONSOLE_PREFIX.//")
      fi
      echo "    ${GREEN}Cluster FQDN:${NC}                        '$CLUSTER_NAME'"

    else
      echo "    ${RED}Cannot determine Route${NC}"
      echo "    ${ORANGE}Check your Kubernetes Configuration${NC}"
      echo "    ${RED}Aborting${NC}"
      exit 1
    fi
fi
echo "---------------------------------------------------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------------------------------------------------"





# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Define some Stuff
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
export CONSOLE_URL=console.$CLUSTER_NAME

export ENTITLED_REGISTRY=cp.icr.io
export ENTITLED_REGISTRY_USER=ekey

export INSTALL_PATH=$TEMP_PATH/cam-$CLUSTER_NAME

export MCM_SERVER=https://icp-console.$CLUSTER_NAME




# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# PRE-INSTALL CHECKS
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "  "
echo "  "
echo "  "
echo "  "
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Pre-Install Checks${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"

POLICY_SCC=$(oc adm policy add-scc-to-user ibm-anyuid-hostpath-scc system:serviceaccount:services:default 2>&1)


echo "    Check ${BLUE}HELM${NC} Version (must be 2.x)"

HELM_RESOLVE=$($HELM_BIN version 2>&1)

if [[ $HELM_RESOLVE =~ "v2." ]];
then
  echo "    ${GREEN}OK${NC}"
else 
  echo "    ${RED}ERROR${NC}: Wrong Helm Version ($HELM_RESOLVE)"
  echo "    ${ORANGE}Trying 'helm2'"

  export HELM_BIN=helm2
  HELM_RESOLVE=$($HELM_BIN version 2>&1)

  if [[ $HELM_RESOLVE =~ "v2." ]];
  then
   echo "    ${GREEN}OK${NC}"
  else 
    echo "    ${RED}ERROR${NC}: Helm Version 2 does not exist in your Path"
    echo "    Please install from https://icp-console.$CLUSTER_NAME/common-nav/cli?useNav=multicluster-hub-nav-nav"
    echo "     or run"
    echo "    curl -sL https://ibm.biz/idt-installer | bash"
    exit 1
  fi
fi



echo "    Check if ${BLUE}cloudctl${NC} Command Line Tool is available"

CLOUDCTL_RESOLVE=$(cloudctl 2>&1)

if [[ $CLOUDCTL_RESOLVE =~ "USAGE" ]];
then
  echo "    ${GREEN}OK${NC}"
else 
  echo "    ${RED}ERROR${NC}: cloudctl Command Line Tool does not exist in your Path"
  echo "    Please install from https://icp-console.$CLUSTER_NAME/common-nav/cli?useNav=multicluster-hub-nav-nav"
  echo "     or run"
  echo "    curl -sL https://ibm.biz/idt-installer | bash"
  exit 1
fi



echo "    Check if ${BLUE}OpenShift${NC} is reachable at               $CONSOLE_URL"

PING_RESOLVE=$(ping -c 1 $CONSOLE_URL 2>&1)


if [[ $PING_RESOLVE =~ "cannot resolve" ]];
then
  echo "    ${RED}ERROR${NC}: Cluster '$CLUSTER_NAME' is not reachable"
  exit 1
else 
  echo "    ${GREEN}OK${NC}"
fi



echo "    Check if OpenShift ${BLUE}KUBECONTEXT${NC} is set for        $CLUSTER_NAME"

KUBECTX_RESOLVE=$(kubectl get routes --all-namespaces 2>&1)


if [[ $KUBECTX_RESOLVE =~ $CLUSTER_NAME ]];
then
  echo "    ${GREEN}OK${NC}"
else 
  echo "    ${RED}ERROR${NC}: Please log into  '$CLUSTER_NAME' via the OpenShift web console"
  exit 1
fi



echo "    Check if ${BLUE}Storage Class${NC} exists on                 $CLUSTER_NAME"

SC_RESOLVE=$(oc get sc 2>&1)


if [[ $SC_RESOLVE =~ $STORAGE_CLASS ]];
then
  echo "    ${GREEN}OK: Storage Class exists${NC}"
else 
  echo "    ${RED}ERROR${NC}: Storage Class $STORAGE_CLASS does not exist on Cluster '$CLUSTER_NAME'. Aborting."
  exit 1
fi


if [[ $SC_RESOLVE =~ (default) ]];
then
  echo "    ${GREEN}OK: Default Storage Class defined${NC}"
else 
  echo "    ${RED}ERROR${NC}: No default Storage Class defined."
  echo "         Define Annotation: storageclass.kubernetes.io/is-default-class=true"
  echo "         ${RED}Aborting.${NC}"
  exit 1
fi




echo "    Check if ${BLUE}ClusterServiceBroker${NC} exists on          $CLUSTER_NAME"

CSB_RESOLVE=$(kubectl api-resources 2>&1)


if [[ $CSB_RESOLVE =~ "servicecatalog.k8s.io" ]];
then
  echo "    ${GREEN}OK${NC}"
else 
  echo "    ${RED}ERROR${NC}: ClusterServiceBroker does not exist on Cluster '$CLUSTER_NAME'. Aborting."
  echo "    Install ClusterServiceBroker on OpenShift 4.2"
  echo "    https://docs.openshift.com/container-platform/4.2/applications/service_brokers/installing-service-catalog.html"
  echo "     "
  echo "   Update 'Removed' to 'Managed'  "
  echo "    KUBE_EDITOR="nano" oc edit servicecatalogapiservers" 
  echo "    KUBE_EDITOR="nano" oc edit servicecatalogcontrollermanagers"
  exit 1
fi



echo "    Check if ${BLUE}Docker Registry Credentials${NC} work ($ENTITLED_REGISTRY_KEY)"
echo "    This might take some time"

DOCKER_LOGIN=$(docker login "$ENTITLED_REGISTRY" -u "$ENTITLED_REGISTRY_USER" -p "$ENTITLED_REGISTRY_KEY" 2>&1)

DOCKER_PULL=$(docker pull cp.icr.io/cp/icp-foundation/mcm-inception:3.2.3 2>&1)
#echo $DOCKER_PULL

if [[ $DOCKER_PULL =~ "pull access denied" ]];
then
echo "${RED}ERROR${NC}: Not entitled for Registry or not reachable"
exit 1
else
  echo "    ${GREEN}OK${NC}"
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"



# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# PREREQUISITES
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "  "
echo "  "
echo "  "
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Install Prerequisites${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"

mkdir -p $INSTALL_PATH 
cd $INSTALL_PATH


echo "  "
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " Create Secret"
kubectl delete secret -n services camsecret
kubectl create secret docker-registry camsecret --docker-username="$ENTITLED_REGISTRY_USER" --docker-password="$ENTITLED_REGISTRY_KEY" --docker-email="test@us.ibm.com" --docker-server="cp.icr.io" -n services

#kubectl describe secret -n services camsecret

echo "  "
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " Create Service Account"
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "camsecret"}]}' -n services

#kubectl describe serviceaccount default -n services
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"




# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# SERVICE ID
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function createToken
{
      export serviceIDName='service-deploy'
      export serviceApiKeyName='service-deploy-api-key'
      cloudctl login -a ${MCM_SERVER} --skip-ssl-validation -u ${MCM_USER} -p ${MCM_PWD} -n services


      cloudctl iam service-id-delete ${serviceIDName} -f
      #cloudctl iam service-api-key-delete ${serviceApiKeyName} ${serviceIDName} -f

      cloudctl iam service-id-create ${serviceIDName} -d 'Service ID for service-deploy'
      cloudctl iam service-policy-create ${serviceIDName} -r Administrator,ClusterAdministrator --service-name 'idmgmt'
      cloudctl iam service-policy-create ${serviceIDName} -r Administrator,ClusterAdministrator --service-name 'identity'
      cloudctl iam service-api-key-create ${serviceApiKeyName} ${serviceIDName} -d 'Api key for service-deploy' > token.txt
}


echo "  "
echo "  "
echo "  "
echo "  "
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Create Service ID${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"

TOKEN_EXISTS=$(ls 2>&1)

if [[ $TOKEN_EXISTS =~ "token.txt" ]];
then
  echo "  ${ORANGE}WARNING${NC}: TOKEN already exists"
  read -p "  Delete and recreate? [y,N]" DO_COMM
  if [[ $DO_COMM == "y" ||  $DO_COMM == "Y" ]]; then
    rm token.txt
    createToken
  fi
else 
  echo "    ${GREEN}OK - Creating TOKEN${NC}"
  createToken
fi

echo "  "
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " Using Service ID TOKEN:"
export SERVICE_TOKEN=$(cat token.txt | tail -1 | awk '{ print $3 }')
echo "    "${RED}$SERVICE_TOKEN${NC}
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"




# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# HELM CHART
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo " "
echo " "
echo " "
echo " "
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Helm Chart${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"

CHART_EXISTS=$(ls 2>&1)

if [[ $CHART_EXISTS =~ $CAM_VERSION ]];
then
  echo "    ${GREEN}OK - Chart already Downloaded${NC}"
else 
  echo "    ${GREEN}Downloading Chart${NC}"
  $HELM_BIN repo add ibm-stable https://raw.githubusercontent.com/IBM/charts/master/repo/stable/
  $HELM_BIN repo update

  $HELM_BIN fetch ibm-stable/ibm-cam --version $CAM_VERSION
fi
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"






# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# CONFIG SUMMARY
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "  "
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${GREEN}CAM will be installed in Cluster ${ORANGE}'$CLUSTER_NAME'${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " ${BLUE}Your configuration${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}CLUSTER :${NC}             $CLUSTER_NAME"
echo "    ${GREEN}REGISTRY TOKEN:${NC}       $ENTITLED_REGISTRY_KEY"
echo "    ----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}MCM Server:${NC}           $MCM_SERVER"
echo "    ${GREEN}MCM User Name:${NC}        $MCM_USER"
echo "    ${GREEN}MCM User Password:${NC}    ************"
echo "    ----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}STORAGE CLASS BLOCK:${NC}  $STORAGE_CLASS_BLOCK"
echo "    ${GREEN}STORAGE CLASS FILE:${NC}   $STORAGE_CLASS_FILE"
echo "    ----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}INSTALL PATH:${NC}         $INSTALL_PATH"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"


echo "  "
echo "  "
echo "  "
echo "  "

echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${RED}Continue Installation with these Parameters? [y,N]${NC}"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}---------------------------------------------------------------------------------------------------------------------------${NC}"
read -p "[y,N]" DO_COMM
if [[ $DO_COMM == "y" ||  $DO_COMM == "Y" ]]; then
  echo "${GREEN}Continue...${NC}"
else
  echo "${RED}Installation Aborted${NC}"
  exit 2
fi


# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# INSTALL
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo ""
echo ""
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " ${ORANGE}Do you want to install CAM into Cluster '$CLUSTER_NAME'?${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"

read -p "Install? [y,N]" DO_COMM
if [[ $DO_COMM == "y" ||  $DO_COMM == "Y" ]]; then


  read -p "Install with Persistence for all (otherwise only for MongoDB)? [y,N]" DO_COMM
  if [[ $DO_COMM == "y" ||  $DO_COMM == "Y" ]]; then
  $HELM_BIN install --name cam ibm-cam-$CAM_VERSION.tgz \
    --namespace services  \
    --set global.image.secretName=camsecret  \
    --set arch=amd64  \
    --set global.iam.deployApiKey=$SERVICE_TOKEN  \
    --set icp.port=443  \
    --set global.audit=false \
    --set camMongoPV.persistence.storageClassName=$STORAGE_CLASS_BLOCK \
    --set camMongoPV.persistence.enabled=true \
    --set camMongoPV.persistence.accessMode=ReadWriteOnce \
    --set camMongoPV.persistence.useDynamicProvisioning=true \
    --set camLogsPV.persistence.useDynamicProvisioning=true \
    --set camLogsPV.persistence.storageClassName=$STORAGE_CLASS_FILE \
    --set camLogsPV.persistence.accessMode=ReadWriteMany \
    --set camTerraformPV.persistence.useDynamicProvisioning=true \
    --set camTerraformPV.persistence.storageClassName=$STORAGE_CLASS_FILE \
    --set camTerraformPV.persistence.accessMode=ReadWriteMany \
    --set camBPDAppDataPV.persistence.useDynamicProvisioning=true \
    --set camBPDAppDataPV.persistence.storageClassName=$STORAGE_CLASS_FILE \
    --set camBPDAppDataPV.persistence.accessMode=ReadWriteMany \
    --tls
  else
    $HELM_BIN install --name cam ibm-cam-$CAM_VERSION.tgz \
    --namespace services  \
    --set global.image.secretName=camsecret  \
    --set arch=amd64  \
    --set global.iam.deployApiKey=$SERVICE_TOKEN  \
    --set icp.port=443  \
    --set global.audit=false \
    --set camMongoPV.persistence.storageClassName=$STORAGE_CLASS_BLOCK \
    --set camMongoPV.persistence.enabled=true \
    --set camMongoPV.persistence.accessMode=ReadWriteOnce \
    --set camMongoPV.persistence.useDynamicProvisioning=true \
    --set camLogsPV.persistence.enabled=false \
    --set camBPDAppDataPV.persistence.enabled=false \
    --set camTerraformPV.persistence.enabled=false \
    --tls
  fi



  echo ""
  echo ""
  echo ""
  echo ""
  echo ""
  echo ""
  echo "${ORANGE}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
  echo "${ORANGE}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
  echo " ${RED}Post Install:${NC} Register CAM into MCM UI in '$CLUSTER_NAME'?"
  echo "${ORANGE}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
  echo "${ORANGE}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
  echo " Please run"
  echo "  ${ORANGE}./tools/automation-navigation-updates.sh -a services${NC}"
  echo ""
  echo ""
else
  echo "${RED}Installation Aborted${NC}"
  echo ""
  echo "${ORANGE}    You can still manually execute:${NC}"
  echo "" 
  echo "    $HELM_BIN install --name cam ibm-cam-$CAM_VERSION.tgz \ "
  echo "    --namespace services  \ "
  echo "    --set global.image.secretName=camsecret  \ "
  echo "    --set arch=amd64  \ "
  echo "    --set global.iam.deployApiKey=$SERVICE_TOKEN  \ "
  echo "    --set icp.port=443  \ "
  echo "    --set camMongoPV.persistence.storageClassName=$STORAGE_CLASS_BLOCK \ "
  echo "    --set camMongoPV.persistence.enabled=true \ "
  echo "    --set camMongoPV.persistence.accessMode=ReadWriteOnce \ "
  echo "    --set camMongoPV.persistence.useDynamicProvisioning=true \ "
  echo "    --set camMongoPV.persistence.storageClassName=$STORAGE_CLASS_BLOCK \ "
  echo "    --set camMongoPV.persistence.enabled=true \ "
  echo "    --set camMongoPV.persistence.accessMode=ReadWriteOnce \ "
  echo "    --set camMongoPV.persistence.useDynamicProvisioning=true \ "
  echo "    --set camLogsPV.persistence.useDynamicProvisioning=true \ "
  echo "    --set camLogsPV.persistence.storageClassName=$STORAGE_CLASS_FILE \ "
  echo "    --set camLogsPV.persistence.accessMode=ReadWriteMany \ "
  echo "    --set camTerraformPV.persistence.useDynamicProvisioning=true \ "
  echo "    --set camTerraformPV.persistence.storageClassName=$STORAGE_CLASS_FILE \ "
  echo "    --set camTerraformPV.persistence.accessMode=ReadWriteMany \ "
  echo "    --set camBPDAppDataPV.persistence.useDynamicProvisioning=true \ "
  echo "    --set camBPDAppDataPV.persistence.storageClassName=$STORAGE_CLASS_FILE \ "
  echo "    --set camBPDAppDataPV.persistence.accessMode=ReadWriteMany \ "
  echo "    --tls "
  echo ""
  echo "    And then run:"
  echo "       ${ORANGE}./tools/automation-navigation-updates.sh -a services${NC}"
  echo "${ORANGE}    ----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
  echo ""
  echo ""
fi



echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " ${ORANGE}Do you want to install additional Tools?${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
read -p "Install? [y,N]" DO_COMM
if [[ $DO_COMM == "y" ||  $DO_COMM == "Y" ]]; then
  echo "  "
  echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
  echo " Install MC plugin for cloudctl"
  curl -kLo cloudctl-mc-plugin https://icp-console.test311-a376efc1170b9b8ace6422196c51e491-0001.eu-de.containers.appdomain.cloud:443/rcm/plugins/mc-darwin-amd64
  cloudctl plugin install -f cloudctl-mc-plugin
  cloudctl mc get cluster
fi
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${GREEN}CAM Installation.... DONE${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${GREEN}To remove release: $HELM_BIN delete cam --purge --tls${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"
echo "${GREEN}***************************************************************************************************************************************************${NC}"




