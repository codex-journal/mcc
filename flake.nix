{
  description = "Marx Compute Club site and infrastructure tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, llm-agents, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      agents = llm-agents.packages.${system};
      buildRevision =
        if self ? rev then self.rev
        else if self ? dirtyRev then self.dirtyRev
        else "unknown";
      buildDirty =
        if self ? dirtyRev then "true"
        else if self ? rev then "false"
        else "unknown";
      siteBuild = pkgs.writeShellApplication {
        name = "mcc-build-site";
        runtimeInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.python3
        ];
        text = ''
          repo_root="''${MCC_REPO_ROOT:-}"
          if [[ -z "$repo_root" ]]; then
            repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
          fi

          cd "$repo_root"
          exec bash scripts/build-site "$@"
        '';
      };
      site = pkgs.stdenvNoCC.mkDerivation {
        pname = "marxcompute-club-site";
        version = "0.1.0";
        src = ./.;
        nativeBuildInputs = [
          pkgs.bash
          pkgs.python3
        ];
        buildPhase = ''
          runHook preBuild
          export MCC_BUILD_REVISION="${buildRevision}"
          export MCC_BUILD_DIRTY="${buildDirty}"
          bash scripts/build-site
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          cp -R dist/. "$out/"
          runHook postInstall
        '';
      };
      sourceNotesFixture = pkgs.stdenvNoCC.mkDerivation {
        pname = "mcc-source-notes-fixture";
        version = "0.1.0";
        src = ./.;
        nativeBuildInputs = [
          pkgs.bash
          pkgs.diffutils
          pkgs.python3
        ];
        buildPhase = ''
          runHook preBuild
          bash scripts/test-source-notes
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          echo ok > "$out/result"
          runHook postInstall
        '';
      };
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
      packages.${system} = {
        default = site;
        site = site;
        build-site = siteBuild;
        dns-tofu = dnsTofu;
      };

      checks.${system} = {
        site = site;
        source-notes-fixture = sourceNotesFixture;
      };

      apps.${system} = {
        build-site = {
          type = "app";
          program = "${siteBuild}/bin/mcc-build-site";
        };

        dns-tofu = {
          type = "app";
          program = "${dnsTofu}/bin/mcc-dns-tofu";
        };
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
            pkgs.python3
            pkgs.util-linux
            pkgs.wrangler
          ];

          shellHook = ''
            echo "MCC shell"
            echo "Site build: scripts/build-site"
            echo "Source notes: add Org files under source-notes/"
            echo "DNS: cd infra/dns && tofu init && tofu plan"
            echo "Signup dev: wrangler pages dev . --binding SIGNUP_ENV=local --persist-to .wrangler/state-rsvp"
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
