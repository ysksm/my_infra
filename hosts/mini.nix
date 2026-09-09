# ホスト固有の設定 (darwin-rebuild switch --flake .#mini)
{ pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Nix 本体は Determinate Nix (determinate-nixd) が管理しているため、
  # nix-darwin 側の Nix 管理を無効にする。両方が有効だと activation が
  # "Determinate detected, aborting activation" で失敗する。
  # 代わりに nix.* オプション (nix.settings や linux-builder) は使えなくなる。
  nix.enable = false;

  # このホストで OrbStack を有効にする
  my-infra.orbstack.enable = true;

  # 開発ツール。nix で入れると /run/current-system/sw/bin に配置され PATH に乗る。
  # (nix-darwin は macOS の path_helper を呼ばないため、公式 .pkg で
  #  /usr/local/go に入れても /etc/paths.d/go が PATH に反映されない)
  # go は 1.26 系を指すため、明示的に 1.27 系を指定する。
  environment.systemPackages = [ pkgs.go_1_27 ];

  # nix-darwin が管理する状態のバージョン。初回適用後は変更しない。
  system.stateVersion = 6;

  # system.primaryUser や users.users.<name> は、ユーザー単位のオプション
  # (homebrew, system.defaults 等) を使う場合にのみ必要。OrbStack を入れる
  # だけなら不要なので設定しない。
}
