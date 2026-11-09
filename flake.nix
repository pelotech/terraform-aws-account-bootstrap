{
  description = "Flake config";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.treefmt-nix.flakeModule ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        { pkgs, ... }:
        let
          # Everything pre-commit needs; this is all CI installs.
          lintTools = with pkgs; [
            # terraform: tenv's proxy installs the version in .terraform-version
            # (min-required: the floor of required_version in versions.tf)
            tenv
            prek
            tflint
            hcledit
            yamllint
            terraform-docs
            actionlint
            zizmor
          ];
          env.TENV_AUTO_INSTALL = "true";
        in
        {
          devShells.ci = pkgs.mkShellNoCC {
            inherit env;
            packages = lintTools;
          };

          devShells.default = pkgs.mkShellNoCC {
            inherit env;
            packages =
              lintTools
              ++ (with pkgs; [
                # sops
                rage
                age-plugin-yubikey
                sops

                # aws
                awscli2
                aws-sso-cli

                just
              ]);
          };

          treefmt = {
            projectRootFile = "flake.nix";
            # OpenTofu's fmt matches terraform fmt and is in the binary cache (terraform is unfree).
            programs.terraform.enable = true;
            programs.terraform.package = pkgs.opentofu;
            programs.nixfmt.enable = true;
          };
        };
    };
}
