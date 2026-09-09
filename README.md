# my_infra

macOS (Apple Silicon) 向けの Nix によるインストール定義。
このリポジトリは定義ファイルのみを管理し、サービスのランタイムデータは含めない。

## 構成

| パス | 内容 |
| --- | --- |
| `flake.nix` | flake 本体。`packages` / `darwinModules` / `darwinConfigurations` を公開 |
| `modules/orbstack.nix` | OrbStack をインストールする nix-darwin モジュール |
| `hosts/mini.nix` | ホスト `mini` 固有の設定 |
| `gitlab/docker-compose.yaml` | セルフホストする GitLab CE の compose 定義 |
| `docs/darwin-rebuild.html` | `darwin-rebuild` コマンドの解説スライド (ブラウザで開く) |
| `docs/orbstack-startup.html` | 適用後に OrbStack を動かすまでの手順スライド |

OrbStack は nixpkgs の `orbstack` パッケージ (unfree、Apple Silicon 専用) を使用する。
インストールされるもの:

- `/Applications/Nix Apps/OrbStack.app`
- `orb` / `orbctl` / `docker` / `kubectl` などの CLI と shell 補完

## 事前準備: Nix のインストール

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

(公式インストーラを使う場合は `sh <(curl -L https://nixos.org/nix/install)` の後、
`~/.config/nix/nix.conf` に `experimental-features = nix-command flakes` を追記する。)

## 使い方

### A. OrbStack だけを入れる

```sh
nix profile install .#orbstack
```

アンインストールは `nix profile remove orbstack`。

### B. nix-darwin で宣言的に管理する (推奨)

初回のみ:

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#mini
```

2 回目以降:

```sh
sudo darwin-rebuild switch --flake .#mini
```

ホスト名が `mini` 以外の場合は `hosts/` にファイルを追加し、`flake.nix` の
`darwinConfigurations` に登録する。

このコマンドの各パーツが何をしているかは `docs/darwin-rebuild.html` にスライドとして
まとめてある。`open docs/darwin-rebuild.html` で閲覧できる。

### 適用したあと

`switch` が成功しても、そのシェルにはまだ PATH が反映されていない。

```sh
exec zsh -l                                  # PATH を反映 (新しいターミナルでも可)
open "/Applications/Nix Apps/OrbStack.app"   # 初回は特権ヘルパーの許可を求められる
docker ps                                    # 空のテーブルが返れば完了
```

`docker compose` (スペース版) は OrbStack の初回起動で `~/.docker/cli-plugins` が
用意されるまで使えない。それまでは `docker-compose` を使う。
手順とトラブルシュートは `docs/orbstack-startup.html` にまとめてある。

### 更新

```sh
nix flake update    # nixpkgs を更新して OrbStack のバージョンを上げる
```

## 補足

- Homebrew 版 OrbStack (`brew install --cask orbstack`) と同居させると
  `/Applications/OrbStack.app` と競合するため、どちらか一方にすること。
- OrbStack 初回起動時は特権ヘルパーのインストールで管理者パスワードを求められる。
- Determinate Nix を使っている場合、`hosts/mini.nix` の `nix.enable = false;` が必須。
  これが無いと activation が `error: Determinate detected, aborting activation` で
  失敗する。代わりに `nix.*` オプション (`nix.settings`、Linux ビルダー等) は
  使えなくなり、Nix 自体の設定は Determinate 側 (`/etc/nix/nix.custom.conf`) で行う。

## サービスのランタイムデータ

コンテナが生成する状態ファイル (データベース・ログ・秘密情報) はリポジトリの外に置く。

| サービス | 配置 |
| --- | --- |
| GitLab | `~/srv/gitlab` (`config` / `data` / `logs`) |

GitLab のデータは以前 `gitlab/data` に置かれていたものを移動した。
`gitlab-secrets.json` や SSH ホスト鍵を含むため、バージョン管理には入れないこと。

## GitLab の起動

OrbStack を入れた後、`docker compose` で起動する。

```sh
cd gitlab && docker compose up -d
```

- Web: http://127.0.0.1:8080 / SSH: ポート 2222
- マウント先は `${HOME}/srv/gitlab` の `config` / `logs` / `data`
