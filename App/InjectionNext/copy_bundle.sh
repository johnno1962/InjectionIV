#!/bin/bash -x
#
#  copy_bundle.sh
#  InjectionIII
#
#  Copies injection bundle for on-device injection.
#  Thanks @oryonatan
#
#  $Id: //depot/HotReloading/copy_bundle.sh#14 $
#

if [ "$CONFIGURATION" == "Debug" ]; then
    # determine which prebuilt bundle to copy
    RESOURCES=${RESOURCES:-"$(dirname "$0")"}
    COPY="$CODESIGNING_FOLDER_PATH/iOSInjection.bundle"
    PLIST="$COPY/Info.plist"
    if [ "$PLATFORM_NAME" == "macosx" ]; then
     BUNDLE=${1:-macOSInjection}
     COPY="$CODESIGNING_FOLDER_PATH/Contents/Resources/macOSInjection.bundle"
     PLIST="$COPY/Contents/Info.plist"
    elif [ "$PLATFORM_NAME" == "appletvsimulator" ]; then
     BUNDLE=${1:-tvOSInjection}
    elif [ "$PLATFORM_NAME" == "appletvos" ]; then
     BUNDLE=${1:-tvOSDevInjection}
    elif [ "$PLATFORM_NAME" == "xrsimulator" ]; then
     BUNDLE=${1:-xrOSInjection}
    elif [ "$PLATFORM_NAME" == "xros" ]; then
     BUNDLE=${1:-xrOSDevInjection}
    elif [ "$PLATFORM_NAME" == "iphoneos" ]; then
     BUNDLE=${1:-iOSDevInjection}
    else
     BUNDLE=${1:-iOSInjection}
    fi

    # copy frameworks used for testing into app's bundle/Frameworks
    rsync -a "$PLATFORM_DEVELOPER_LIBRARY_DIR"/*Frameworks/{XC,StoreKit}* "$PLATFORM_DEVELOPER_USR_DIR/lib"/*.dylib "$CODESIGNING_FOLDER_PATH/Frameworks/" &&
    codesign -f --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp\=none --preserve-metadata\=identifier,entitlements,flags --generate-entitlement-der "$CODESIGNING_FOLDER_PATH/Frameworks"/{XC*,StoreKit*,*.dylib};
    
    # Xcode 16's new SwiftTesting framework
    TESTING="$PLATFORM_DEVELOPER_LIBRARY_DIR/Frameworks/Testing.Framework"
    if [ -d "$TESTING" ]; then
      rsync -a "$TESTING"/* "$CODESIGNING_FOLDER_PATH/Frameworks/Testing.framework/"
      codesign -f --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp\=none --preserve-metadata\=identifier,entitlements,flags --generate-entitlement-der "$CODESIGNING_FOLDER_PATH/Frameworks/Testing.framework";
    fi
    
    # Make copy of "PlugIns" directory when testing
    PLUGINS="/tmp/PlugIns.$PRODUCT_NAME.$PLATFORM_NAME"
    LAST_PLUGINS="/tmp/InjectionNext.PlugIns"
    rm -f $LAST_PLUGINS
    if [ -d "$CODESIGNING_FOLDER_PATH/PlugIns" ]; then
     (sleep 5; while
      rsync -va "$CODESIGNING_FOLDER_PATH/PlugIns"/* "$PLUGINS/" |
      grep -v /sec | grep /; do sleep 15; done) 1>/dev/null 2>&1 &
    else
     # Xcode 16 deletes PlugIns directory, link to copy
     ln -s $PLUGINS $LAST_PLUGINS
    fi

    # copy prebuilt bundle into app package and codesign
    rsync -a "$RESOURCES/$BUNDLE.bundle"/* "$COPY/" &&
    /usr/libexec/PlistBuddy -c "Add :UserHome string $HOME" "$PLIST" &&
    codesign -f --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp\=none --preserve-metadata\=identifier,entitlements,flags --generate-entitlement-der "$COPY" &&
    defaults write com.johnholdsworth.InjectionNext codesigningIdentity "$EXPANDED_CODE_SIGN_IDENTITY"
fi
