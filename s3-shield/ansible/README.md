# Deploying via ansible

[ansible](https://ansible.readthedocs.io/en/latest/) allows you to copy files, and manage services on fleets of servers that you have `ssh` access to.

## Requirements

- `ansible` installed on the deploying host
- `python3` installed on the servers to be deployed
- either a [Varnish Enterprise repository token](https://docs.varnish-software.com/varnish-enterprise/installation/), or Varnish Enterprise must be installed on the servers to be deployed.

## Get started

First, update `s3.conf` as explained in the top [README](../README.md).

Then, update `inventory.yaml` with the list of servers you wish to deploy. It's a regular [Ansible inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html), the example provided uses `yaml` but you can pick the format you want.
If you wish to install Varnish Enterprise too, provide the installation token.

You can now deploy:
``` shell
ansible-playbook -i inventory.yaml playbook.yaml
```

You can now try to fetch a file from any of the deployed servers: http://server_address/path/to/your/file.png
