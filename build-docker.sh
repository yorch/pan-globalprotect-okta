#!/bin/bash

IMAGE="${1:-gp-okta}"

docker build -t ${IMAGE} .
