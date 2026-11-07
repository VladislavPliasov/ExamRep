#!/bin/bash
set -euxo pipefail

dnf -y install docker
systemctl enable --now docker

aws ecr get-login-password --region ${region} \
  | docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${region}.amazonaws.com

docker pull ${repository}:${image_tag}

docker rm -f todoai 2>/dev/null || true
docker run -d --restart=always --name todoai -p 80:80 ${repository}:${image_tag}
