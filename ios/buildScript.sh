#!/bin/sh

frameworks="OAuthSwift"

source "${SRCROOT}/Pods/Target Support Files/Pods-OAuthManager/Pods-OAuthManager-frameworks.sh"
FRAMEWORKS_FOLDER_PATH=""

for framework in $frameworks
do

install_framework "${SRCROOT}/Pods/$framework"

done
