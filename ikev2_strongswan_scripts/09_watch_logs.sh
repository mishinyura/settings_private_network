#!/usr/bin/env bash
set -Eeuo pipefail

sudo journalctl -u strongswan-starter -f
