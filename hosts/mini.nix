# ホスト固有の設定 (darwin-rebuild switch --flake .#mini)
{ ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Nix 本体は Determinate Nix (determinate-nixd) が管理しているため、
  # nix-darwin 側の Nix 管理を無効にする。両方が有効だと activation が
  # "Determinate detected, aborting activation" で失敗する。
  # 代わりに nix.* オプション (nix.settings や linux-builder) は使えなくなる。
  nix.enable = false;

  # このホストで OrbStack を有効にする
  my-infra.orbstack.enable = true;

  # nix-darwin が管理する状態のバージョン。初回適用後は変更しない。
  system.stateVersion = 6;

  # system.primaryUser や users.users.<name> は、ユーザー単位のオプション
  # (homebrew, system.defaults 等) を使う場合にのみ必要。OrbStack を入れる
  # だけなら不要なので設定しない。
}
