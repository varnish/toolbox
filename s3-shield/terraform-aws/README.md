# Deploy on AWS via terraform and cloud-init

[terraform](https://www.terraform.io/) is an automation tool which allows you to manage cloud resources (spin up instances, create security groups, etc.) in cloud environment. The tool is extremely versatile, but we'll focus here on using it to deploy on AWS, using Varnish Enterprise AMIs.

## Requirements

`terraform`, that's it.

## Getting started

We first need to generate the cloud-init, there you need to edit `../cloud-init/s3.conf`, and then generate the `yaml` file that `terraform` will use:

``` bash
../cloud-init/generate_yaml.sh
```

Next, edit `variables.tf` to at least modify the `KEY_NAME` value to match your IAM key pair. You can also tweak the instance type and the region where to spawn it.

To deploy:

``` shell
terraform init
terraform plan
terraform apply
```

The output should end with something like:

```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

instance_private_ip_addr = "172.31.18.28"
instance_public_ip_addr = "35.85.51.82"
```

In this case, your file will be accessible at http://35.85.51.82/path/to/your/file.png
