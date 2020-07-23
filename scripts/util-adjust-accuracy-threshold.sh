#!/bin/bash

set -e -u -o pipefail

declare NEW_THRESHOLD=${1:-}

if [[ -z "${NEW_THRESHOLD}" ]]; then
    echo "Usage: $0 <NEW_ACCURACY_THRESHOLD>"
    echo "where <NEW_ACCURACY_THRESHOLD> is the minimum percentage accurate the model can be"
    exit 1
fi

echo "Applying new threshold of ${NEW_THRESHOLD}%."

# do the decimal arithmetic (need to delegate to bc for this)
declare -r DECIMAL_THRESHOLD=$(echo "scale=4; $NEW_THRESHOLD / 100" | bc)

# NOTE: Not a namespaced resource
oc patch AIModelAccuracyThreshold/model-accuracy-threshold --type='json' \
    -p="[{'op' : 'replace', 'path' : '/spec/parameters/accuracyThreshold', 'value' : ${DECIMAL_THRESHOLD}}]"