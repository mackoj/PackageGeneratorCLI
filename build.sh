#!/usr/bin/env bash

CLI="package-generator-cli"
INFOJSONPATH="$CLI.artifactbundle/info.json"
CLIBINPATH="$CLI.artifactbundle/arm64-apple-macosx/bin"
TMPPATH=$(mktemp)
TMPRELEASEFOLDER=$(mktemp -d)
TMPRELEASEPROJECT=$TMPRELEASEFOLDER/PackageGeneratorCLI
TAG=$(curl -s "https://api.github.com/repos/mackoj/PackageGeneratorCLI/tags" | jq --compact-output --raw-output '.[0].name ')
SOURCEFOLDER=$(pwd)

cd "$TMPRELEASEFOLDER" || exit
git clone --depth 1 --branch "$TAG"  https://github.com/mackoj/PackageGeneratorCLI.git
cd "$TMPRELEASEPROJECT" || exit

echo "Building $TAG"
git checkout "$TAG"

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
cp $CLI.artifactbundle.zip "$SOURCEFOLDER/$CLI.artifactbundle.zip"
cd "$SOURCEFOLDER" || exit
rm -rf "$TMPRELEASEFOLDER"
