#!/usr/bin/env bash


# prepare variables
CLI="package-generator-cli"
INFOJSONPATH="$CLI.artifactbundle/info.json"
TMPPATH=$(mktemp)
TMPRELEASEFOLDER=$(mktemp -d)
TMPRELEASEPROJECT=$TMPRELEASEFOLDER/PackageGeneratorCLI
TAG=$(curl -s "https://api.github.com/repos/mackoj/PackageGeneratorCLI/tags" | jq --compact-output --raw-output '.[0].name ')
SOURCEFOLDER=$(pwd)

if [[ $(uname -m) == "x86_64" ]]; then
	TRIPLE="x86_64-apple-macosx"
else
	TRIPLE="arm64-apple-macosx"
fi

CLIBINPATH="$CLI.artifactbundle/$TRIPLE/bin"
ZIPOUTPUT=$CLI-$TRIPLE.artifactbundle.zip

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

echo "Updating Artifactbundle Info.json"
jq '.artifacts."package-generator-cli".version = "'"$TAG"'"' "$INFOJSONPATH" > "$TMPPATH"
mv "$TMPPATH" "$INFOJSONPATH"

jq '.artifacts."package-generator-cli".variants += [{ "path": ""'"$TRIPLE"'"/bin/package-generator-cli", "supportedTriples": [""'"$TRIPLE"'""] }] ' "$INFOJSONPATH" > "$TMPPATH"
mv "$TMPPATH" "$INFOJSONPATH"

echo "Zip Artifactbundle"
zip -r $ZIPOUTPUT $CLI.artifactbundle -x ".*" -x "__MACOSX"

echo "Compute Checksum"
swift package compute-checksum $ZIPOUTPUT

echo "Cleaning"
rm -rf $CLI.artifactbundle
cp $CLI.artifactbundle.zip "$SOURCEFOLDER/$CLI.artifactbundle.zip"
cd "$SOURCEFOLDER" || exit
rm -rf "$TMPRELEASEFOLDER"
