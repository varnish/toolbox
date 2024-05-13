#! /usr/bin/env python
import logging
import random
import threading
import time
import uuid

import requests

varnish_root = "http://varnish:80/"
def cool_guy(idx):
    while True:
        unique = uuid.uuid4()
        headers = {'cool-guy': str(unique)}
        logging.info("cool guy %s: starting", idx)
        for animal in ["puppy", "kitten", "otter", "red_panda"]:
            payload = { 'animal': animal }
            requests.get(f"{varnish_root}", params=payload, headers=headers)
            time.sleep(0.2)
        logging.info("cool guy %s: finishing", idx)
        time.sleep(1 + random.random())

def evil_dude(idx):
    while True:
        unique = uuid.uuid4()
        headers = {'evil-dude': str(unique)}
        logging.info("cool guy %s: starting", idx)
        for animal in ["puppy", "kitten", "otter", "red_panda"] * 20:
            payload = { 'animal': animal }
            requests.get(f"{varnish_root}", params=payload, headers=headers)
        logging.info("cool guy %s: finishing", idx)
        time.sleep(60 * random.random())

threads = []

n_cool_guys = 5

for i in range(n_cool_guys):
    threads.append(threading.Thread(target=cool_guy, args=(i,)))

n_evil_dudes = 1
for i in range(n_evil_dudes):
    threads.append(threading.Thread(target=evil_dude, args=(i,)))

for t in threads:
    t.start()

for t in threads:
    t.join()
