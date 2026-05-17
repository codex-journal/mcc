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
      dnsTofu = pkgs.writeShellApplication {
        name = "mcc-dns-tofu";
        runtimeInputs = [
          pkgs.git
          pkgs.opentofu
        ];
        text = ''
          if [[ -n "''${CLOUDFLARE_API_TOKEN:-}" ]]; then
            export TF_VAR_cloudflare_account_api_token="''${TF_VAR_cloudflare_account_api_token:-$CLOUDFLARE_API_TOKEN}"
            export TF_VAR_cloudflare_zone_api_token="''${TF_VAR_cloudflare_zone_api_token:-$CLOUDFLARE_API_TOKEN}"
          fi

          if [[ -n "''${CLOUDFLARE_DNS_API_TOKEN:-}" ]]; then
            export TF_VAR_cloudflare_account_api_token="''${TF_VAR_cloudflare_account_api_token:-$CLOUDFLARE_DNS_API_TOKEN}"
            export TF_VAR_cloudflare_zone_api_token="''${TF_VAR_cloudflare_zone_api_token:-$CLOUDFLARE_DNS_API_TOKEN}"
          fi

          repo_root="''${MCC_REPO_ROOT:-}"
          if [[ -z "$repo_root" ]]; then
            repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
          fi

          exec tofu -chdir="$repo_root/infra/dns" "$@"
        '';
      };
    in
    {
      packages.${system}.dns-tofu = dnsTofu;

      apps.${system}.dns-tofu = {
        type = "app";
        program = "${dnsTofu}/bin/mcc-dns-tofu";
      };

      devShells.${system} = {
        default = pkgs.mkShell {
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

        dns = pkgs.mkShell {
          packages = [
            dnsTofu
            pkgs.curl
            pkgs.git
            pkgs.jq
            pkgs.opentofu
          ];

          shellHook = ''
            echo "MCC DNS shell"
            echo "Brokered plan: with-secret cloudflare-mcx nix run .#dns-tofu -- plan"
          '';
        };
      };
    };
}
