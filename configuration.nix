{ lib, system, pkgs, ... }:

let
  builder = pkgs.writeShellScriptBin "builder" (builtins.readFile ./build.sh);
in
{
  boot.binfmt.emulatedSystems = []
    ++ lib.lists.optional (system == "x86_64-linux") "aarch64-linux"
    ++ lib.lists.optional (system == "aarch64-linux") "x86_64-linux";

  environment.systemPackages = with pkgs; [
    builder
    attic-client
    jq
  ];
}
