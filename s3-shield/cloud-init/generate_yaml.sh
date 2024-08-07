#!/bin/bash

# cd where this script it
cd $(dirname "$0")

BASE64_VCL=$(base64 -w 0 "../default.vcl")
BASE64_S3CONF=$(base64 -w 0 "s3.conf")
INSTALL_VARNISH_TOKEN="$1"

sed -e "s/BASE64_VCL_CONTENT/$BASE64_VCL/" \
    -e "s/BASE64_S3CONF_CONTENT/$BASE64_S3CONF/" \
    -e "s/INSTALL_VARNISH_TOKEN/$INSTALL_VARNISH_TOKEN/" \
    cloud-init-s3-shield.yaml.tmpl > cloud-init-s3-shield.yaml

echo $(dirname "$0")/cloud-init-s3-shield.yaml has been created
