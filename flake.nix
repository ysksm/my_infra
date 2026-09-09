{
  description = "my_infra - macOS 向けの Nix 定義 (OrbStack)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
    }:
    let
      # OrbStack は Apple Silicon 版のみ配布されている
      system = "aarch64-darwin";

      pkgs = import nixpkgs {
        inherit system;
        # OrbStack は unfree ライセンスなので個別に許可する
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "orbstack";
      };
    in
    {
      # nix profile install .#orbstack / nix build .#orbstack で単体導入する場合
      packages.${system} = {
        inherit (pkgs) orbstack;
        default = pkgs.orbstack;
      };

      # 他の nix-darwin 構成から import して使えるモジュール
      darwinModules.orbstack = ./modules/orbstack.nix;

      # darwin-rebuild switch --flake .#mini で適用する構成
      darwinConfigurations.mini = nix-darwin.lib.darwinSystem {
        modules = [
          self.darwinModules.orbstack
          ./hosts/mini.nix
        ];
      };
    };
}
