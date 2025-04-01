#!/usr/bin/env bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPTDIR"

# Remove existing files

find \
  -not -path "./.git/*" \
  -not -name ".git" \
  -not -name "./.github/*" \
  -not -name ".github" \
  -not -name "generate.sh" \
  -not -name ".gitignore" \
  -delete

# Generate

out="."

expr=$(cat <<'EOF'
with { inherit (import <nixpkgs> {}) fetchFromGitHub; };

fetchFromGitHub {
  owner = "NixOS";
  repo = "nixpkgs";
  rev = "6af28b834daca767a7ef99f8a7defa957d0ade6f"; # nixpkgs-rev
  hash = "sha256-W4YZ3fvWZiFYYyd900kh8P8wU6DHSiwaH0j4+fai1Sk="; # nixpkgs-sha256
}
EOF
)

fullNixpkgs=$(nix-build --expr "$expr")
echo "Got full Nixpkgs: ${fullNixpkgs}"

NIX_PATH="nixpkgs=$fullNixpkgs"
export NIX_PATH

expr=$(cat <<-END
with { inherit (import <nixpkgs> {}) fetchFromGitHub fetchgit symlinkJoin; };

symlinkJoin {
  name = "slim-nixpkgs-path-closure";
  paths = [
    (fetchFromGitHub {
      owner = "NixOS";
      repo = "nixpkgs";
      rev = "6d3fc36c541ae715d43db5c1355890f39024b26f";
      sha256 = "sha256-cRsIC0Ft5McBSia0rDdJIHy3muWqKn3rvjFx92DU2dY=";
    })

    (fetchgit {
      url = "https://github.com/NixOS/nixpkgs";
      rev = "6d3fc36c541ae715d43db5c1355890f39024b26f";
      sha256 = "sha256-cRsIC0Ft5McBSia0rDdJIHy3muWqKn3rvjFx92DU2dY=";
    })
  ];
}

END
)

files=$(nix-build -vv -E "$expr" --store /tmp/test1 --no-out-link 2>&1 | grep -o -P "$fullNixpkgs/[^']*" | sort | uniq)

for file in $files; do
    relPath=$(realpath --relative-to="$fullNixpkgs" "$file")
    mkdir -p "$out/$(dirname "$relPath")"
    cp "$file" "$out/$relPath"
done

# Extra files
cp "$fullNixpkgs/.version" "$out"
