#!/bin/bash

# cd where this script it
cd $(dirname "$0")

BASE64_VCL=$(base64 -w 0 "../default.vcl")
BASE64_S3CONF=$(base64 -w 0 "s3.conf")

if [ -n "$1" ]
then
  INSTALL_VARNISH_COMMAND="curl https:\/\/docs.varnish-software.com\/scripts\/setup\.sh \| TOKEN=$1 INSTALL=\"varnish\-plus\" bash"
else
  INSTALL_VARNISH_COMMAND="echo 'Not installing Varnish Enterprise, assuming it is already installed'"
fi

sed -e "s/BASE64_VCL_CONTENT/$BASE64_VCL/" \
    -e "s/BASE64_S3CONF_CONTENT/$BASE64_S3CONF/" \
    -e "s/INSTALL_VARNISH_COMMAND/$INSTALL_VARNISH_COMMAND/" \
    cloud-init-s3-shield.yaml.tmpl > cloud-init-s3-shield.yaml

echo $(dirname "$0")/cloud-init-s3-shield.yaml has been created
