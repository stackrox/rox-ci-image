#!/bin/sh

cci-export() {
    if [ -z "$BASH_ENV" ]; then
        echo >&2 "Env var BASH_ENV not properly set"
        return 1
    fi

    if [ "$#" -ne 2 ]; then
    	echo >&2 "Usage: $0 KEY VALUE"
    fi

    key="$1"
    value="$2"

	export "${key}=${value}"
    echo "export ${key}=$(printf '%q' "$value")" >> "$BASH_ENV"
}
