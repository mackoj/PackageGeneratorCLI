#!/usr/bin/env bash

CLI="package-generator-cli"
swift build -c release
mkdir -p $CLI.artifactbundle/arm64-apple-macosx/bin
cp -f .build/release/$CLI $CLI.artifactbundle/arm64-apple-macosx/bin
cp info.json $CLI.artifactbundle/info.json
zip -r $CLI.artifactbundle.zip $CLI.artifactbundle -x ".*" -x "__MACOSX"
swift package compute-checksum $CLI.artifactbundle.zip
rm -rf $CLI.artifactbundle
