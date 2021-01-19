#! /bin/bash

cd $(dirname $0)

IBMCLOUD=$(pwd)/Bluemix_CLI/bin/ibmcloud
CF=~/.bluemix/.cf/cfcli/cf
#BLUE="\e[00;34m"
#RED="\e[00;31m"
#END="\e[0m"
BLUE=""
RED=""
END="==================================="

if [ ! -f "$IBMCLOUD" ]; then
    echo "${BLUE}download ibm-cloud-cli-release${END}"
    ver=$(curl -s https://github.com/IBM-Cloud/ibm-cloud-cli-release/releases/latest | grep -Po "(\d+\.){2}\d+")
    #ver=1.1.0
    wget -q -Oibm_cli.tgz https://clis.cloud.ibm.com/download/bluemix-cli/$ver/linux64
    if [ $? -eq 0 ]; then
        tar xzf ibm_cli.tgz
    else
        echo "${RED}download new version failed!${END}"
        exit 1
    fi
    rm -fv ibm_cli.tgz
fi

# set default env
IBM_MEMORY=${IBM_MEMORY:-"128M"}
V2_ID=${V2_ID:-"d007eab8-ac2a-4a7f-287a-f0d50ef08680"}
V2_PATH=${V2_PATH:-"path"}
ALTER_ID=${ALTER_ID:-"1"}
VLESS_EN=${VLESS_EN:-"false"}
mkdir -p $IBM_APP_NAME

if [ ! -f "./config/v2ray" ]; then
    echo "${BLUE}download v2ray${END}"
    pushd ./config
    new_ver=$(curl -s https://github.com/v2fly/v2ray-core/releases/latest | grep -Po "(\d+\.){2}\d+")
    wget -q -Ov2ray.zip https://github.com/v2fly/v2ray-core/releases/download/v${new_ver}/v2ray-linux-64.zip
    if [ $? -eq 0 ]; then
        7z x v2ray.zip v2ray v2ctl *.dat
        chmod 700 v2ctl v2ray
    else
        echo "${RED}download new version failed!${END}"
        exit 1
    fi
    rm -fv v2ray.zip
    popd
fi

# cloudfoundry config
cp -rvf ./config/manifest.yml ./$IBM_APP_NAME/
sed "s/IBM_APP_NAME/${IBM_APP_NAME}/" ./$IBM_APP_NAME/manifest.yml -i
sed "s/IBM_MEMORY/${IBM_MEMORY}/" ./$IBM_APP_NAME/manifest.yml -i

# v2ray config
cp -vf ./config/v2ray ./$IBM_APP_NAME/$IBM_APP_NAME
cp -vf ./config/v2ctl ./$IBM_APP_NAME/

branch=${GITHUB_REF#refs/heads/}
if [ $VLESS_EN == "false" ]; then
    {
        echo "#! /bin/bash"
        echo "wget -Oconfig.json https://raw.githubusercontent.com/$GITHUB_REPOSITORY/$branch/config/config_vmess.json"
        echo "sed 's/V2_ID/$V2_ID/' config.json -i"
        echo "sed 's/V2_PATH/$V2_PATH/' config.json -i"
        echo "sed 's/ALTER_ID/$ALTER_ID/' config.json -i"
    } > ./$IBM_APP_NAME/d.sh
else
    {
        echo "#! /bin/bash"
        echo "wget -Oconfig.json https://raw.githubusercontent.com/$GITHUB_REPOSITORY/$branch/config/config_vless.json"
        echo "sed 's/V2_ID/$V2_ID/' config.json -i"
        echo "sed 's/V2_PATH/$V2_PATH/' config.json -i"
    } > ./$IBM_APP_NAME/d.sh
fi
chmod +x ./$IBM_APP_NAME/d.sh

#cat ./$IBM_APP_NAME/d.sh
#exit 0

if [ ! -f "$CF" ]; then
    echo "${BLUE}ibmcloud cf install${END}"
    $IBMCLOUD cf install -f
fi

echo "${BLUE}cf login${END}"
$CF login -a https://api.us-south.cf.cloud.ibm.com <<EOF
$IBM_ACCOUNT
EOF

cd ./$IBM_APP_NAME
echo "${BLUE}cf push${END}"
$CF push

if [ $? -ne 0 ]; then
    echo "${BLUE}print cf push error${END}"
    $CF logs $IBM_APP_NAME --recent
    exit 1
fi
