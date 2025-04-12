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
  -not -name "test.nix" \
  -not -name "test-fetch-only.nix" \
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

STORE=/Users/tom/store1
sudo rm -rf "$STORE"

nix-build -vv -E "$expr" --store "$STORE" --no-out-link --substituters https://cache.nixos.org > all_build_output.txt 2>&1

cat all_build_output.txt | grep -o "$fullNixpkgs/[^']*" | sort | uniq > log_files.txt

while IFS= read -r file; do
  echo "Processing: $file"

  relPath=$(python3 -c "import os.path; print(os.path.relpath('$file', '$fullNixpkgs'))")

  if [[ -d "$file" ]]; then
    mkdir -p "$file"
  else
    mkdir -p "$out/$(dirname "$relPath")"
    cp "$file" "$out/$relPath"
  fi
done < "log_files.txt"

# Extra files
cp "$fullNixpkgs/.version" "$out"

# Needed for fetchgit apparently
mkdir -p "pkgs/os-specific/darwin/apple-source-releases"
touch "pkgs/os-specific/darwin/apple-source-releases/.gitkeep"
