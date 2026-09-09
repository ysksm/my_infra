# OrbStack (Docker Desktop の代替 / Linux VM ランタイム) を宣言的にインストールする
# nix-darwin モジュール。
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my-infra.orbstack;
in
{
  options.my-infra.orbstack = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "OrbStack をインストールするかどうか。";
    };

    package = lib.mkPackageOption pkgs "orbstack" { };
  };

  config = lib.mkIf cfg.enable {
    # OrbStack は unfree ライセンス。OrbStack だけを許可する。
    nixpkgs.config.allowUnfreePredicate = lib.mkDefault (pkg: lib.getName pkg == "orbstack");

    # /Applications/Nix Apps に OrbStack.app が、PATH に orb / orbctl / docker /
    # kubectl などのラッパーが入る。
    environment.systemPackages = [ cfg.package ];
  };
}
