# What it is
This module contains executable statements, function definitions, methods that are used for authentication, accessing and refreshing of tokens, and querying endpoints from the Varnish Controller.

# What you need to run and maintain the module
- Varnish Controller instance
- Main python script that will use this module
# Example YAML file
```
# config.yaml
endpoint: https://api.demo.varnish.cloud:443
username: your-own-username
password: your-own-password
organization: your-own-org
```
# Example python script that outputs the apilogs
```
# get_agent_logs.py
import vcli    # <-- This imports the vcli.py module
import time

v = vcli.Vcli.from_yaml("config.yaml")

def fetch_apilogs(token):
    apilogs = v.query_endpoint("/apilogs", {"msg":"*wrong*"})

    if apilogs:
        for log in apilogs:
            print(f"{log['id']} {log['createdAt']} message:{log['msg']}")
    else:
        print("No apilogs available.")
        return None

while True:
    token = v.refresh_token()

    if token:
        fetch_apilogs(token)
    else:
        print("Failed to authenticate or retrieve token.")
    time.sleep(5)
```
# How it works
Run your script that has `import vcli`
```
python3 get_agent_logs.py
```
The sample script will load the configuration from `config.yaml`. Depending on the logs that you have on your Controller instance and the filter you have for the parameters, this script should output something like this:

```
98 2024-10-03T02:05:21.691173Z message:wrong user or password
99 2024-10-03T02:22:54.070717Z message:wrong user or password
```
# API
## vcli.Vcli(username, password, endpoint, organization=None)
Initializes a `Vcli` object that will hold authentication details to facilitate querying the Controller API without having to constantly re-login.

**Parameters:**
- username/password (str): mandatory credential information, (e.g. "login"/"pw1234")
- endpoint (str): Controller API base URL, (e.g. "https://api.demo.varnish.cloud:443/api/v1")
- organization (str): represents the Organization for Controller authentication (optional)

### vcli.Vcli.query_endpoint(ep, params=None)
A `vcli.Vcli` method that requests the specified [Controller API endpoint](https://api.demo.varnish.cloud/docs/index.html), using authentication information provided when the `vcli.Vcli` object was created. The returned data will be a JSON object, according to the REST API.

**Parameters:**
- ep (str): API endpoint to query, (e.g. "/apilogs", "/agents")
- params (dict): query parameters that can be used to filter requests in key:value pairs, (e.g. {"msg":"wrong"}. (optional)

## vcli.Vcli.from_yaml(yaml_file=None, password=None)

Alternative constructor for the `vcli.Vcli` class, using the configuration file format from the actual `vcli` command.

**Parameters:**
- yaml_file: path to the YAML config file (defaults to `~/.vcli.yml`)
- password: password to override or complement the data in the `yaml` file (optional)

The `password` argument may be omitted if the configuration file includes a `password` field, or a `passwordfile` field.
