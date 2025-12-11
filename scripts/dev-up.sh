#!/usr/bin/env bash
set -euo pipefail

if [ ! -f .env ]; then
  echo ".env not found, copying from .env.example"
  cp .env.example .env
  echo "Created .env from .env.example. You may want to tweak values."
fi

docker compose up --build
