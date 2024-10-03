# This module can eventually be used by doing "import vcli" in your python script
import requests
import time
import yaml
import os
import sys

# Read config vars from a yaml file, otherwise it will use ~/.vcli.yml by default
def config_file(yaml_file=None):
    if yaml_file is None:
        yaml_file = "~/.vcli.yml"
    yaml_file = os.path.expanduser(yaml_file)

    with open(yaml_file, "r") as file:
        config = yaml.safe_load(file)

    # Check for required key(s)
    required_config = ["username", "endpoint"]
    missing_config = [key for key in required_config if key not in config]
    if missing_config:
        raise Exception(f"missing {', '.join(missing_config)} key in file {yaml_file}")

    return config

class Vcli:
    def __init__(self, username, password, endpoint, organization=None):
        self.username = username
        self.password = password
        self.organization = organization
        self.accessToken = None
        self.accessExpire = 0

        self.endpoint = f"{endpoint}/api/v1"
        self.auth_endpoint = "/auth/login"
        self.login_url = f"{self.endpoint}{self.auth_endpoint}"

        self.refresh_token()


    @classmethod
    def from_yaml(cls, yaml_file=None, password=None):
        config = config_file(yaml_file)

        password_from_file = config.get("password")
        passwordfile = config.get("passwordfile")

        if password:
            pass
        elif password_from_file:
            password = password_from_file
        elif passwordfile:
            passwordfile = os.path.expanduser(passwordfile)
            with open(passwordfile, "r") as file:
                password = file.read().strip()
        else:
            raise Exception("missing password, or password or passwordfile in file")

        return cls(config.get("username"), password, config.get("endpoint"), config.get("organization"))

    def refresh_token(self):
        # Reuse the existing token if it's still valid
        if time.time() < (self.accessExpire - 60):  # 1 minute margin for expiration of accessToken
            return self.accessToken

        else:
            body = {"org": self.organization} if self.organization else None
            try:
                response = requests.post(self.login_url, data=body, auth=(self.username, self.password))
                response.raise_for_status()
                r = response.json()
                self.accessExpire = r.get('accessExpire')
                self.accessToken = r.get('accessToken')

                return self.accessToken

            except requests.RequestException as e:
                raise Exception(f"Login failed: {e}")
                return None

    def query_endpoint(self, ep, params=None):
        url = f"{self.endpoint}{ep}"

        # check if token is valid?
        token = self.refresh_token()

        headers = {"Authorization": f"Bearer {token}"}
        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()

            return response.json()

        except requests.RequestException as e:
            print(f"Error fetching agents: {e}")
