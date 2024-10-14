#=========================================================================#
# shell.nix
#
# To create shell environment and install packages run in project directory
# where this file is located:
#
#   $ echo "use nix" > .envrc && direnv allow
#
#   $ nix-shell
#   $ nix-shell --show-trace
#
#=========================================================================#
#
# See also:
#
#   - https://nix.dev/tutorials/first-steps/declarative-shell.html#a-basic-shell-nix-file
#   - https://nix.dev/guides/recipes/direnv#automatic-direnv
#
let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-24.05";
  pkgs = import nixpkgs {
    config = {};
    overlays = [];
  };
  # `mkShellNoCC`
  # - function produces a temporary environment without a compiler toolchain.
  # - it is a wrapper around `mkDerivation`
in
  pkgs.mkShellNoCC {
    packages = with pkgs; [
      # using luajit2.1

      #dependency
      love

      #dev_dependency
      luajitPackages.busted # Elegant Lua unit testing. see https://lunarmodules.github.io/busted/
      luajitPackages.luaunit # A unit testing framework for Lua. see http://github.com/bluebird75/luaunit

      #misc
      pkg-config
      cowsay
      lolcat
    ];

    # Environment variables
    GREETING = "Hello from shell.nix!";

    # - note: use `shellHook` attribute to override protected environment variables.
    shellHook = ''
      echo $GREETING | cowsay | lolcat
    '';

    # Instead of manually activating the environment for each project, you can
    # reload a declarative shell every time you enter the project's directory
    # or chage the `shell.nix` inside it.
  }

