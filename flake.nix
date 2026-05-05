{
  description = "Marx Compute Club site and infrastructure tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.git
          pkgs.gh
          pkgs.jq
          pkgs.opentofu
        ];

        shellHook = ''
          echo "MCC shell"
          echo "DNS: cd infra/dns && tofu init && tofu plan"
        '';
      };
    };
}

