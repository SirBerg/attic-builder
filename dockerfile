FROM nixos/nix
WORKDIR /etc/nixos
COPY ./ ./
RUN nixos-rebuild switch --flake .#default

CMD [ "builder" ]
