#!/usr/bin/env bash
# prints the name (unless -s|--silent) and value of the variable given as parameter

key="FOO"
value="$FOO"
sflag=0

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -s|--silent) sflag=1
        ;;
    *)  key="$1"; value="${!1}"
        ;;
  esac
  shift
done

if (( sflag == 0 )); then
  echo -n "$key: "
fi
echo "$value"
