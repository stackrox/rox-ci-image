#!/usr/bin/env bash
# This script demonstrates ACTUAL bash variable resolution precedence when
# using 'BASH_ENV' and 'export'.
#
# The intent is to understand precisely the default behavior, and to better
# communicate the purpose and function of the 'cci-export' utility.

export SHELL="/bin/bash"
export BASH_ENV="/tmp/bash-env.sh"

cat > "$BASH_ENV" <<EOF
export FOO="value from bash_env"
export BAR="value from bash_env"
EOF

export FOO=foo  # var def should override def in BASH_ENV
unset BAR       # var def will originate in BASH_ENV only, not defined locally
export BAZ=baz  # var def will be inherited by subshell, not defined in BASH_ENV

echo "----"
(env | grep BASH_ENV)  # inherited
(env | grep FOO)       # resolves to local (overrides definition in BASH_ENV)
(env | grep BAR)       # resolves to definition in BASH_ENV (no local def)
(env | grep BAZ)       # inherited

echo "----"
(eval 'echo "BASH_ENV : [$BASH_ENV]"')   # inherited
(eval 'echo "FOO      : [$FOO]"')
(eval 'echo "BAR      : [$BAR]"')
(eval 'echo "BAZ      : [$BAZ]"')

echo "----"
bash -c 'echo "BASH_ENV : [$BASH_ENV]"'  # inherited
bash -c 'echo "FOO      : [$FOO]"'
bash -c 'echo "BAR      : [$BAR]"'
bash -c 'echo "BAZ      : [$BAZ]"'

# Bash env variable loading order:
# 1. vars inherited from parent process
# 2. vars defined in BASH_ENV
# 3. local vars (including BASH_ENV var overrides)

# Therefore the variable lookup precedence in the current shell is:
# 1. local vars (because they override BASH_ENV)
# 2. BASH_ENV
# 3. vars exported by parent process

# And the variable lookup precedence in a subshell is:
# 1. bash_env
# 2. local
