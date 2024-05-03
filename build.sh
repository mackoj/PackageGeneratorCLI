#!/usr/bin/env bash


# prepare variables
CLI="package-generator-cli"
INFOJSONPATH="$CLI.artifactbundle/info.json"
TMPPATH=$(mktemp)
TMPRELEASEFOLDER=$(mktemp -d)
REPO="mackoj/PackageGeneratorCLI"
SOURCEFOLDER=$(pwd)

if [[ $(uname -m) == "x86_64" ]]; then
	TRIPLE="x86_64-apple-macosx"
else
	TRIPLE="arm64-apple-macosx"
fi

TMPRELEASEPROJECT=$TMPRELEASEFOLDER/PackageGeneratorCLI
TAG=$(curl -s "https://api.github.com/repos/$REPO/tags" | jq --compact-output --raw-output '.[0].name ')
# TAG="feat/testTargetImports"
CLIBINPATH="$CLI.artifactbundle/$TRIPLE/bin"
ZIPOUTPUT=$CLI-$TRIPLE.artifactbundle.zip

# generation
############
echo "Cloning $REPO @ $TAG"
cd "$TMPRELEASEFOLDER" || exit
git clone --depth 1 --branch "$TAG"  https://github.com/$REPO.git
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

jq '.artifacts."package-generator-cli".variants += [{ "path": "'"$TRIPLE"'/bin/package-generator-cli", "supportedTriples": ["'"$TRIPLE"'"] }] ' "$INFOJSONPATH" > "$TMPPATH"
mv "$TMPPATH" "$INFOJSONPATH"

echo "Zip Artifactbundle"
zip -r $ZIPOUTPUT $CLI.artifactbundle -x ".*" -x "__MACOSX"
cp $ZIPOUTPUT "$SOURCEFOLDER/$ZIPOUTPUT"

echo "Cleaning"
rm -rf $CLI.artifactbundle
cd "$SOURCEFOLDER" || exit
rm -rf "$TMPRELEASEFOLDER"

echo "Compute Checksum"
swift package compute-checksum $ZIPOUTPUT
