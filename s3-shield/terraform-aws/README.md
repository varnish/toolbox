## Getting started


1. Edit the ``../cloud-init/s3.conf`` to match your AWS environment
2. Generate the yaml configuration, later required by Terraform, as shown below 

``` shell
$ ../cloud-init/generate_yaml.sh
```

---

## Provision the infra

``` shell
$ terraform init
$ terraform plan -var="key_name=your-key-name"
$ terraform apply -var="key_name=your-key-name"
```

The output should end with something like:

```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

instance_private_ip_addr = "172.31.18.28"
instance_public_ip_addr = "35.85.51.82"
```

In this case, your file will be accessible at http://35.85.51.82/path/to/your/file.png

--- 

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| aws | ~> 6.11 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.11 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ami\_owners | Varnish Software marketplace image | `list(string)` | <pre>[<br/>  "679593333241"<br/>]</pre> | no |
| key\_name | Add your key in Key pairs in AWS | `string` | n/a | yes |
| region | n/a | `string` | `"us-west-2"` | no |
| ve6\_instance | n/a | `string` | `"t3.micro"` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance\_private\_ip\_addr | n/a |
| instance\_public\_ip\_addr | n/a |
<!-- END_TF_DOCS -->
