#!/usr/bin/env bash

CLI="package-generator-cli"
INFOJSONPATH="$CLI.artifactbundle/info.json"
CLIBINPATH="$CLI.artifactbundle/arm64-apple-macosx/bin"
TMPPATH=$(mktemp)
TAG=$(curl -s "https://api.github.com/repos/mackoj/PackageGeneratorCLI/tags" | jq --compact-output --raw-output '.[0].name ')


echo "Building $TAG"
git checkout $TAG

echo "Building $TAG"
swift build -c release

echo "Creating Artifactbundle"
mkdir -p $CLIBINPATH
cp -f .build/release/$CLI $CLIBINPATH
cp info.json "$INFOJSONPATH"
jq '.artifacts."package-generator-cli".version = "'"$TAG"'"' "$INFOJSONPATH" > "$TMPPATH"
mv "$TMPPATH" "$INFOJSONPATH"

echo "Zip Artifactbundle"
zip -r $CLI.artifactbundle.zip $CLI.artifactbundle -x ".*" -x "__MACOSX"

echo "Compute Checksum"
swift package compute-checksum $CLI.artifactbundle.zip

echo "Cleaning"
rm -rf $CLI.artifactbundle
