#!/bin/bash
# Stream NotchlyV2 app logs

LOG_COUNT=${1:-50}

log stream --predicate 'process == "NotchlyV2"' --style compact 2>&1 | head -n "$LOG_COUNT"
