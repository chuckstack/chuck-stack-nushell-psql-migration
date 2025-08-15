{ pkgs ? import <nixpkgs> {} }:

# Simple shell.nix to get the correct fetchgit hash
# Usage: nix-shell get-hash.nix
# The error message will show the correct hash

let
  # Use branch name (e.g., "main"), tag, or specific commit hash - "HEAD" won't work with fetchgit
  targetCommit = "e309c1ac019cf7afeb549eebb6367215aaf471cb";
  
  # Intentionally wrong hash to trigger error with correct hash
  migrationUtilSrc = pkgs.fetchgit {
    url = "https://github.com/chuckstack/chuck-stack-nushell-psql-migration";
    rev = targetCommit;
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # Wrong on purpose!
  };

in pkgs.mkShell {
  buildInputs = [ migrationUtilSrc ];
}