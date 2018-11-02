argsOuter@{...}:
let
  # specifying args defaults in this slightly non-standard way to allow us to include the default values in `args`
  args = rec {
    pkgs = import <nixpkgs> {};
    pythonPackages = pkgs.python36Packages;
    localOverridesPath = ./local.nix;
  } // argsOuter;
in (with args; {
  digitalMarketplaceJenkinsEnv = (pkgs.stdenv.mkDerivation rec {
    name = "digitalmarketplace-jenkins-env";
    shortName = "dm-jenkins";
    buildInputs = [
      pythonPackages.python
      pkgs.libffi
      pkgs.libyaml
      # pip requires git to fetch some of its dependencies
      pkgs.git
      # for `cryptography`
      pkgs.openssl
      pkgs.cacert
      # because we *actually* also depend on the credentials repo
      pkgs.sops
      # for tput, used in Makefile
      pkgs.ncurses
      # ansible makes use of rsync & ssh
      pkgs.openssh
      pkgs.rsync
      ((import ./aws-auth.nix) (with pkgs; { inherit stdenv fetchFromGitHub makeWrapper jq awscli openssl; }))
    ];

    hardeningDisable = pkgs.stdenv.lib.optionals pkgs.stdenv.isDarwin [ "format" ];

    GIT_SSL_CAINFO="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    VIRTUALENV_ROOT = "venv${pythonPackages.python.pythonVersion}";
    VIRTUAL_ENV_DISABLE_PROMPT = "1";
    SOURCE_DATE_EPOCH = "315532800";

    # if we don't have this, we get unicode troubles in a --pure nix-shell
    LANG="en_GB.UTF-8";

    shellHook = ''
      export PS1="\[\e[0;36m\](nix-shell\[\e[0m\]:\[\e[0;36m\]${shortName})\[\e[0;32m\]\u@\h\[\e[0m\]:\[\e[0m\]\[\e[0;36m\]\w\[\e[0m\]\$ "

      if [ ! -e $VIRTUALENV_ROOT ]; then
        ${pythonPackages.python}/bin/python -m venv $VIRTUALENV_ROOT
      fi
      source $VIRTUALENV_ROOT/bin/activate
      pip install --upgrade pip==18.0  # e.g. pynacl is sensitive to "old" pips
      make requirements
    '';
  }).overrideAttrs (if builtins.pathExists localOverridesPath then (import localOverridesPath args) else (x: x));
})
