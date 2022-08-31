#!/usr/bin/env bash
# This script demonstrates ACTUAL bash variable resolution precedence when
# using 'BASH_ENV' and 'export' in a non-interactive execution environment.
#
# The intent is to understand precisely the default behavior, corner cases,
# and to clearly communicate the purpose and function of the 'cci-export'
# utility.
#
# https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html
# https://man7.org/linux/man-pages/man1/bash.1.html#COMMAND_EXECUTION_ENVIRONMENT

export SHELL="/bin/bash"
export BASH_ENV="/tmp/bash-env.sh"

cat > "$BASH_ENV" <<EOF
export FOO="value from bash_env"
export BAR="value from bash_env"
EOF

export FOO=foo  # var def should override def in BASH_ENV
unset BAR       # var def will originate in BASH_ENV only
export BAZ=baz  # var def will be inherited by subshell
static/usr/local/bin/cci-export QUX qux  # BASH_ENV only

echo
echo "----[subshell basic]----"
(env | grep PS1)       # verified subshell is non-interactive
(env | grep BASH_ENV)  # inherited BUT NOT SOURCED!
(env | grep FOO)       # resolves to LOCAL val because BASH_ENV is not sourced
(env | grep BAR)       # resolves to EMPTY val because BASH_ENV is not sourced
(env | grep BAZ)       # resolves to LOCAL val because that is the only def
(env | grep QUX)       # resolves to EMPTY val because BASH_ENV is not sourced

echo
echo "----[subshell with 'eval']----"
(eval 'echo "PS1      : [$PS1]"')        # verified subshell is non-interactive
(eval 'echo "BASH_ENV : [$BASH_ENV]"')   # inherited BUT NOT SOURCED!
(eval 'echo "FOO      : [$FOO]"')        # resolves to LOCAL val because BASH_ENV is not sourced
(eval 'echo "BAR      : [$BAR]"')        # resolves to EMPTY val because BASH_ENV is not sourced
(eval 'echo "BAZ      : [$BAZ]"')        # resolves to LOCAL val because that is the only def
(eval 'echo "QUX      : [$QUX]"')        # resolves to LOCAL val because BASH_ENV is not sourced

echo
echo "----[subshell with 'bash -c']----"
bash -c 'echo "PS1      : [$PS1]"'       # verified subshell is non-interactive
bash -c 'echo "BASH_ENV : [$BASH_ENV]"'  # inherited and sourced
bash -c 'echo "FOO      : [$FOO]"'       # resolves to BASH_ENV def
bash -c 'echo "BAR      : [$BAR]"'       # resolves to BASH_ENV def
bash -c 'echo "BAZ      : [$BAZ]"'       # resolves to LOCAL val because that is the only def
bash -c 'echo "QUX      : [$QUX]"'       # resolves to BASH_ENV def
static/usr/local/bin/cci-export QUX hello
bash -c 'echo "QUX      : [$QUX]"'       # resolves to updated BASH_ENV def ('hello')

echo
echo "----[script invocation]----"
cat > /tmp/helper.sh <<'EOF'
#!/usr/bin/env bash
echo "PS1      : [$PS1]"
echo "BASH_ENV : [$BASH_ENV]"
echo "FOO      : [$FOO]"
echo "BAR      : [$BAR]"
echo "BAZ      : [$BAZ]"
echo "QUX      : [$QUX]"
EOF
static/usr/local/bin/cci-export QUX world
bash /tmp/helper.sh  # same results as prev block using 'bash -c'


echo
cat <<EOF
Conclusions:
* BASH_ENV is sourced ONLY for non-interactive SCRIPT invocations (not subshells)
* BASH_ENV overrides vars inherited via 'export'
* BASH_ENV vars can be overridden in the current execution environment
EOF
