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
| `redmine/docker-compose.yaml` | セルフホストする Redmine (PostgreSQL) の compose 定義 |
| `redmine/redminectl` | Redmine の運用スクリプト (setup / backup / restore / update など) |
| `docs/darwin-rebuild.html` | `darwin-rebuild` コマンドの解説スライド (ブラウザで開く) |
| `docs/orbstack-startup.html` | 適用後に OrbStack を動かすまでの手順スライド |
| `docs/go-path.html` | .pkg で入れた Go が `command not found` になった原因と対処のスライド |
| `docs/redmine-ops.html` | Redmine を macOS で運用する手順のスライド (起動・バックアップ・更新・復旧) |

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
- nix-darwin は macOS 標準の `/etc/zprofile` を差し替え、`path_helper` を呼ばなくなる。
  そのため公式 .pkg インストーラが `/etc/paths.d/` に置いたパス (Go、Wireshark、
  VMware Fusion など) は PATH に反映されない。CLI ツールは `.pkg` ではなく
  `environment.systemPackages` で入れること。Go は `hosts/mini.nix` で
  `pkgs.go_1_27` を指定している (`pkgs.go` は 1 世代前を指すため系列を明示)。
  経緯は `docs/go-path.html` を参照。

## サービスのランタイムデータ

コンテナが生成する状態ファイル (データベース・ログ・秘密情報) はリポジトリの外に置く。

| サービス | 配置 |
| --- | --- |
| GitLab | `~/srv/gitlab` (`config` / `data` / `logs`) |
| Redmine | `~/srv/redmine` (`files` / `plugins` / `themes` / `db`) |

GitLab のデータは以前 `gitlab/data` に置かれていたものを移動した。
`gitlab-secrets.json` や SSH ホスト鍵を含むため、バージョン管理には入れないこと。

## GitLab の起動

OrbStack を入れた後、`docker compose` で起動する。

```sh
cd gitlab && docker compose up -d
```

- Web: http://127.0.0.1:8080 / SSH: ポート 2222
- マウント先は `${HOME}/srv/gitlab` の `config` / `logs` / `data`

## Redmine の起動と運用

Redmine 6 と PostgreSQL 16 を `docker compose` で動かす。操作は `redmine/redminectl` に
まとめてあり、手順の全体は `docs/redmine-ops.html` にスライドとしてまとめてある。

```sh
cd redmine
./redminectl setup            # 初回: .env 生成 → ~/srv/redmine 作成 → 起動 → HTTP 200 を待つ
./redminectl status           # コンテナ状態と HTTP 応答
./redminectl backup           # DB ダンプ + 添付 + .env を ~/srv/redmine-backup/<日時>/ へ (14 世代保持)
./redminectl schedule-backup  # launchd で毎日 03:00 に backup
./redminectl restore <dir>    # backup ディレクトリから復元 (DB を作り直す。確認あり)
./redminectl update           # backup → pull → up (migration は起動時に自動)
./redminectl plugins          # ~/srv/redmine/plugins に置いたプラグインの migration
```

- Web: http://127.0.0.1:3000 (初期ユーザー `admin` / `admin`、初回ログインで変更を求められる)
- `.env` (git 管理外) に DB パスワードと `secret_key_base` を持つ。`setup` が乱数で生成する。
  `REDMINE_SECRET_KEY_BASE` を変えるとセッションと暗号化済み設定が無効になるため、
  backup に `env` として同梱している
- マウント先は `${HOME}/srv/redmine` の `files` (添付) / `plugins` / `themes` / `db` (PostgreSQL)。
  `.env` の `REDMINE_DATA_DIR` で変更できる
- バックアップ先・世代数は `REDMINE_BACKUP_DIR` / `REDMINE_BACKUP_KEEP` で変更できる
