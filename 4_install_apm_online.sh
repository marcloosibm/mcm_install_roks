# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Install Script for ICAM on IBM ROKS Cloud
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
export APM_VERSION=1.6.0

# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Default Values
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
export TEMP_PATH=$TMPDIR
export HELM_BIN=helm
export STORAGE_CLASS=ibmc-block-gold
export MCM_USER=admin
export MCM_PWD=passw0rd



# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# Do Not Edit Below
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "  "
echo " ${GREEN}APM Install for OpensHift 4.2${NC}"
echo "  "
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
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
  echo " ${BLUE}Determining Cluster FQN${NC}"
  echo "---------------------------------------------------------------------------------------------------------------------------"
    CLUSTER_ROUTE=$(kubectl get routes console -n openshift-console | tail -n 1 2>&1 ) 
    if [[ $CLUSTER_ROUTE =~ "reencrypt" ]];
    then
      CLUSTER_FQDN=$( echo $CLUSTER_ROUTE | awk '{print $2}')
      if [[ $(uname) =~ "Darwin" ]];
      then
          CLUSTER_NAME=$(echo $CLUSTER_FQDN | sed -e "s/console.//")
      else
          CLUSTER_NAME=$(echo $CLUSTER_FQDN | sed "s/console.//")
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

export INSTALL_PATH=$TEMP_PATH/apm-$CLUSTER_NAME

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
POLICY_SCC=$(oc adm policy add-scc-to-user ibm-anyuid-hostpath-scc system:serviceaccount:kube-system:default 2>&1)


echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
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



echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
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



echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
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

export SCRIPT_PATH=$(pwd)

mkdir -p $INSTALL_PATH 
cd $INSTALL_PATH

cp $SCRIPT_PATH/tools/apm-ibm-cloud-appmgmt-prod-cacerts.yaml .

echo "  "
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " Create Secret"
kubectl delete secret -n kube-system apmsecret
kubectl create secret docker-registry apmsecret --docker-username="$ENTITLED_REGISTRY_USER" --docker-password="$ENTITLED_REGISTRY_KEY" --docker-email="test@us.ibm.com" --docker-server="cp.icr.io" -n kube-system

#kubectl describe secret -n kube-system apmsecret

echo "  "
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " Create Service Account"
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "apmsecret"}]}' -n kube-system

#kubectl describe serviceaccount default -n kube-system
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

if [[ $CHART_EXISTS =~ $APM_VERSION ]];
then
  echo "    ${GREEN}OK - Chart already Downloaded${NC}"
else 
  echo "    ${GREEN}Downloading Chart${NC}"
  echo "cloudctl login -a ${MCM_SERVER} --skip-ssl-validation -u ${MCM_USER} -p ${MCM_PWD} -n kube-system"
  cloudctl login -a ${MCM_SERVER} --skip-ssl-validation -u ${MCM_USER} -p ${MCM_PWD} -n kube-system
  $HELM_BIN repo add ibm-entitled-charts https://raw.githubusercontent.com/IBM/charts/master/repo/entitled/
  $HELM_BIN repo update
  $HELM_BIN fetch ibm-entitled-charts/ibm-cloud-appmgmt-prod --version $APM_VERSION
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
echo " ${GREEN}APM will be installed in Cluster ${ORANGE}'$CLUSTER_NAME'${NC}"
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
echo "    ${GREEN}STORAGE CLASS:${NC}        $STORAGE_CLASS"
echo "    ----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "    ${GREEN}INSTALL PATH:${NC}         $INSTALL_PATH"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"



# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# INSTALL
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo ""
echo ""
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " ${ORANGE}Do you want to install APM into Cluster '$CLUSTER_NAME'?${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"

read -p "Install? [y,N]" DO_COMM
if [[ $DO_COMM == "y" ||  $DO_COMM == "Y" ]]; then

    $HELM_BIN install --name apm ibm-cloud-appmgmt-prod-1.6.0.tgz \
    --namespace kube-system  \
    --set global.license="accept"  \
    --set global.ingress.domain="icp-console.$CLUSTER_NAME"  \
    --set global.ingress.port="443"  \
    --set global.icammcm.ingress.domain="icp-proxy.$CLUSTER_NAME"  \
    --set global.masterIP="icp-console.$CLUSTER_NAME"  \
    --set global.masterPort="443"  \
    --set ibm-cem.icpbroker.adminusername="admin"  \
    --set global.image.pullSecret=apmsecret  \
    --set createTLSCerts="true"  \
    --tls & 2>&1

    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo "${ORANGE}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
    echo "${ORANGE}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
    echo " ${RED}Post Install:${NC} Patch Certificate Config Map '$CLUSTER_NAME'?"
    echo "${ORANGE}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
    echo "${ORANGE}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"

    CONFIGMAP_RESOLVE=$(kubectl get configmap apm-ibm-cloud-appmgmt-prod-cacerts -n kube-system 2>&1)
    while [[ $CONFIGMAP_RESOLVE =~ "Error" ]]; do 
      CONFIGMAP_RESOLVE=$(kubectl get configmap apm-ibm-cloud-appmgmt-prod-cacerts -n kube-system 2>&1)
      echo "   Waiting for ConfigMap" && sleep 1; 
    done
    kubectl apply -f ./apm-ibm-cloud-appmgmt-prod-cacerts.yaml

    echo ""
    echo ""

else
    echo "${RED}Installation Aborted${NC}"
fi


echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo " ${GREEN}APM Installation.... DONE${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"


echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo " ${ORANGE}Registering APM Installation${NC}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
read -p "Are all pods running? (This can take a looooooooong time) [y,N]" DO_COMM
if [[ $DO_COMM == "y" ||  $DO_COMM == "Y" ]]; then
  echo "  "
  echo "----------------------------------------------------------------------------------------------------------------------------------------------------"
  echo " Registering APM Installation"
  kubectl exec -n kube-system -t `kubectl get pods -l release=apm -n kube-system | grep "apm-ibm-cem-cem-users" | grep "Running" | head -n 1 | awk '{print $1}'` bash -- "/etc/oidc/oidc_reg.sh" "`echo $(kubectl get secret platform-oidc-credentials -o yaml -n kube-system | grep OAUTH2_CLIENT_REGISTRATION_SECRET: | awk '{print $2}')`"
  kubectl exec -n kube-system -t `kubectl get pods -l release=apm -n kube-system | grep "apm-ibm-cem-cem-users" | grep "Running" | head -n 1 | awk '{print $1}'` bash -- "/etc/oidc/registerServicePolicy.sh" "`echo $(kubectl get secret apm-cem-service-secret -o yaml -n kube-system | grep cem-service-id: | awk '{print $2}')`" "`cloudctl tokens --access`"
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
echo " ${GREEN}DONE${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"
echo "${GREEN}----------------------------------------------------------------------------------------------------------------------------------------------------${NC}"



