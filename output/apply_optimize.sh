#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' 'No optimization plan has been generated or approved.' >&2
printf '%s\n' 'Run tools/inspect_system.sh on the target Debian machine first.' >&2
exit 1
