#!/usr/bin/env bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPTDIR"

# Remove existing files

find -not -path "./.git/*" \
  -not -name ".git" \
  -not -name "generate.sh" \
  -delete

# Generate

fullNixpkgs="$1"
out="."

NIX_PATH="nixpkgs=$fullNixpkgs"
export NIX_PATH

fetchFromGitHubExpr=$(cat <<-END
with { inherit (import <nixpkgs> {}) fetchFromGitHub symlinkJoin; };

let
  expr1 = fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "6d3fc36c541ae715d43db5c1355890f39024b26f";
    sha256 = "sha256-cRsIC0Ft5McBSia0rDdJIHy3muWqKn3rvjFx92DU2dY=";
  };

in

symlinkJoin {
  name = "slim-nixpkgs-path-closure";
  paths = [expr1];
}

END
)

files=$(nix-build -vv -E "$fetchFromGitHubExpr" 2>&1 | grep -o -P "$fullNixpkgs/[^']*" | sort | uniq)

for file in $files; do
    relPath=$(realpath --relative-to="$fullNixpkgs" "$file")
    mkdir -p "$out/$(dirname "$relPath")"
    cp "$file" "$out/$relPath"
done

# Extra files
cp "$fullNixpkgs/.version" "$out"
