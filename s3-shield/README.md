# S3 shield

This VCL offers a quick and easy way to configure Varnish Enterprise as an [S3](https://aws.amazon.com/s3/) (or compatible) caching layer. This is useful to save time and money by serving your data from a local Varnish node (or several), rather that fetching the object from S3 every time.

This README explains the VCL logic itself, and each subdirectory offers an example on how to deploy on multiple platforms. Those READMEs will focus on the platform-specific details of each deployments.

# Prerequisites

## S3 bucket, private or public

You should start by having access to an S3 bucket. It can be either private and protected by a key+secret, requiring requests to it to be signed, or it could be an open bucket that you lock down through network policy.

In either case, make sure you have access to files in the storage before trying to add Varnish in front of it.

## Varnish Enterprise

The provided VCL requires [Varnish Enterprise](https://www.varnish-software.com/products/varnish-enterprise/) to run as it relies on Enterprise vmods. Therefore you will need either a subscription or to run compatible AMIs on the various markeplaces.

# Configuration

## s3.conf

The main file is name `s3.conf` and you'll find a template in each of the subdirectories for convenience. It'll look like this:

``` ini
s3_bucket_address = bucket_name.s3.region.amazonaws.com:443
s3_ttl = 100s
aws_access_key_id = AKIA*********
aws_secret_access_key = *******************
```

There's a very limited amount of options, and most of them are optional, here's the list:
- s3_bucket_address: the URL of your bucket, without the protocol (it's infer from the port), and it should be in the form `bucket_name.s3.region.amazonaws.com:443`
- s3_ttl: how long should Varnish cache the objects from the storage
- aws_access_key_id/aws_secret_access_key (optional): the secret and key that Varnish should use to sign requests. If absent, Varnish just won't sign requests.
- algorithm (optional): for Google Cloud Storage, set it to `GOOG4-RSA-SHA256`, but it should be ignored for fully S3-compatible storage.

## default.vcl and environment

The VCL (`default.vcl`) doesn't need to be modified, but it needs to be told where to find `s3.conf`. This is done with two environment variables: `AWS_SHARED_CREDENTIALS_FILE` and `AWS_CONFIG_FILE` which are both set to the path of `s3.conf`.

In its most simplistic form, running the S3 shield looks like this:

``` bash
export AWS_SHARED_CREDENTIALS_FILE=/etc/varnish/s3.conf
export AWS_CONFIG_FILE=/etc/varnish/s3.conf
varnishd -F -f /etc/varnish/default.vcl -a :6081
```

you can check the subdirectories to see platform specific implementations.
