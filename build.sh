#!/usr/bin/env bash


# INPUTS_ATTIC_URL: url of the attic server: example "https://attic.example.tld/"
# INPUTS_ATTIC_CACHE: name of the attic cache: example "default"
# INPUTS_ATTIC_TOKEN: token from the attic server: example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
# INPUTS_INSTALL_DEPS: if deps should be installed or not: example: true
# INPUTS_LITTLE_SPACE: if nix store should be cleaned after every build: example true
# INPUTS_FLAKE_PATH: path to flake folder: example "./"
# INPUT_CRON: cron time: example "0 0 * * *"

PWD=$(pwd)
if [[ $INPUTS_FLAKE_PATH == "" ]]; then
  INPUTS_FLAKE_PATH=$1
fi

create_cron_entry() {
  echo "$INPUT_CRON $0 $INPUTS_FLAKE_PATH" | crontab -
}

install_deps() {
  nix-env -iA attic-client -f '<nixpkgs>'
}

free_space() {
  if [[ $INPUTS_LITTLE_SPACE == 'true' ]]; then
    echo Deleting old paths...
    rm -rf \
      ./result \
      ~/.cache/nix

    nix store gc 
    nix store optimise
  fi
}

login() {
  if ! attic cache info $INPUTS_ATTIC_CACHE; then
    echo Configuring attic client...
    attic login local $INPUTS_ATTIC_URL $INPUTS_ATTIC_TOKEN
  fi
}

push() {
  echo Pushing ...
  attic push $INPUTS_ATTIC_CACHE ./result
}

build_packages() {
  # Prepare VARS
  PACKAGE_ARCHS=$(nix flake show --json 2> /dev/null | jq -r '.packages | keys[]' | tr '\n' ' ')
  SUPPORTED_ARCHS_REGEX="^($(echo $system$(cat /etc/nix/nix.conf | grep extra-platforms | cut -d "=" -f 2) | tr " " "|"))$"

  # Build Packages
  if [[ "$PACKAGE_ARCHS" != "" ]]; then
    for ARCH in $PACKAGE_ARCHS; do
      if [[ "$ARCH" =~ $SUPPORTED_ARCHS_REGEX ]]; then
        PACKAGES=$(nix flake show --json 2> /dev/null | jq -r '.packages["'"$ARCH"'"] | keys[]' | tr '\n' ' ')

        if [[ "$PACKAGES" != "" ]]; then
          for PACKAGE in $PACKAGES; do
            echo Building $ARCH.$PACKAGE
            nix build --accept-flake-config .\#packages.$ARCH.$PACKAGE --max-jobs 2
            if [ $? -eq 0 ]; then
              echo $ARCH.$PACKAGE was build!
              push
              # Frees up space if $INPUTS_LITTLE_SPACE is true
              free_space
            else
              echo $ARCH.$PACKAGE build failed!
            fi
              echo
              echo
          done
        else
          echo No packages for arch $ARCH in flake found!
        fi
      else
        echo $ARCH is not supported on your system!
      fi
    done
  else
    echo No packages in flake found!
  fi
}

build_systems() {
  # Prepare VARS
  SYSTEMS=$(nix flake show --json 2> /dev/null | jq -r '.nixosConfigurations | keys[]' | tr '\n' ' ')
  
  if [[ "$SYSTEMS" != "" ]]; then
    # Build systems
    for SYSTEM in $SYSTEMS; do
      echo Building $SYSTEM ...
      nix build --accept-flake-config .\#nixosConfigurations.$SYSTEM.config.system.build.toplevel --max-jobs 2
      if [ $? -eq 0 ]; then
        echo $SYSTEM was build!
        push
        # Frees up space if $INPUTS_LITTLE_SPACE is true
        free_space
      else
        echo $SYSTEM build failed!
      fi
      echo
      echo
    done
  else
    echo No systems in flake found!
  fi
}

main() {
  if [ ! -d $INPUTS_FLAKE_PATH ]; then 
    echo $INPUTS_FLAKE_PATH is not a vaild path
    echo Usage: $0 [Path to Directory with flake]
    exit 1
  fi

  if [[ $INPUTS_CRON != "" ]]; then
    create_cron_entry
  fi

  if [[ $INPUTS_INSTALL_DEPS == true ]]; then
    install_deps
  fi

  login

  if [[ "$INPUTS_FLAKE_PATH" != "" ]]; then
    cd $INPUTS_FLAKE_PATH
  fi

  if [[ ($INPUTS_BUILD_SYSTEMS == 'true') || ($INPUTS_BUILD_SYSTEMS == '') ]]; then
    build_systems
  fi

  if [[ $INPUTS_BUILD_PACKAGES == 'true' || ($INPUTS_BUILD_PACKAGES == '') ]]; then
    build_packages
  fi
  
  if [[ "$INPUTS_FLAKE_PATH" != "" ]]; then
    cd $PWD
  fi
}

main
