# This is the BashRC file for the container.

# cci-export is a function which can be used to export environment variables in a way that is persistent
# across CircleCI steps.
cci-export() {
	if [ "$#" -ne 2 ]; then
		echo >&2 "Usage: $0 KEY VALUE"
	fi

	key="$1"
	value="$2"

	export "${key}=${value}"

	if [ "$CIRCLECI" == "true" ]; then
		if [ -z "$BASH_ENV" ]; then
			echo >&2 "Env var BASH_ENV not properly set"
			return 1
		fi
		echo "export ${key}=$(printf '%q' "$value")" >> "$BASH_ENV"
	fi
}
