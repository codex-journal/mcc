{
  description = "Marx Compute Club site and infrastructure tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, llm-agents, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      agents = llm-agents.packages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          agents.agent-browser
          pkgs.curl
          pkgs.git
          pkgs.gh
          pkgs.jq
          pkgs.nodejs_22
          pkgs.opentofu
          pkgs.wrangler
        ];

        shellHook = ''
          echo "MCC shell"
          echo "DNS: cd infra/dns && tofu init && tofu plan"
          echo "Signup dev: wrangler pages dev . --config wrangler.local.jsonc"
        '';
      };
    };
}
