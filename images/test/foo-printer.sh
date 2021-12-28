#!/usr/bin/env bash

if [[ -n "$1" ]]; then
  echo "$1: ${!1}"
else
  echo "FOO: $FOO"
fi
