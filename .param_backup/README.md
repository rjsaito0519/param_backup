# param 個人バックアップ

`/home/had/sryuta/analyzer/JPARC2025E72/param`（param サブモジュール、`e72` ブランチ）を
`/group/had/sks/Users/sryuta/backup/param` に rsync し、変更があればそこで git commit する。
GitHub（`git@github.com:rjsaito0519/param_backup.git`, `main`）への push は手動。

このディレクトリは param リポジトリでは `.git/info/exclude`
（`/gpfs/home/had/sryuta/analyzer/JPARC2025E72/.git/modules/submodule/param/info/exclude`）で除外されており、
param リポジトリの git 管理外。バックアップ先には rsync でコピーされ commit される。

## 仕組み

- 定期実行は cron（毎時 0 分）で、cw01-08 のうち **1 台だけ**に登録する。cron 行のマーカーは `# e72-param-backup`。
- rsync は `fieldmap`、`.git`、`.param_backup/.discord_webhook`、エディタの一時ファイルを除外する。
- SRC のブランチが `e72` でなくてもバックアップは実行される（ログに WARN が出るだけ）。
- 状態ファイル（ログ・lock・Discord メッセージ ID）は `/home/had/sryuta/.config/e72-param-backup/`。
- 二重起動は `backup.lock` の flock で防いでいる。

## cron の管理（全ノード横断）

このディレクトリの `cron_start.sh` / `cron_stop.sh` / `cron_monitor.sh` は**今いるノードしか見ない**。
他ノードにある登録に気づかないまま二重登録してしまうので、cron の登録先の確認・変更は
analyzer 側の全ノード対応スクリプトで `--marker` を付けて行う。

```bash
B=/home/had/sryuta/analyzer/JPARC2025E72/.backup_script

$B/monitor.sh                                      # 全ノードの cron 一覧（DUPLICATE も表示）
$B/cron_start.sh --move cw01 --marker e72-param-backup   # 登録先を付け替え
$B/cron_stop.sh  --marker e72-param-backup               # 全ノードから削除
$B/cron_stop.sh  --marker e72-param-backup cw06          # 指定ノードからだけ削除
```

新規登録（どのノードにも登録がない状態から）は、全ノードに登録がないことを
`$B/monitor.sh` で確認してから、登録したいノードでこのディレクトリの `./cron_start.sh` を実行する。

## よく使うコマンド

```bash
cd /home/had/sryuta/analyzer/JPARC2025E72/param/.param_backup

./backup_param.sh                  # 手動で 1 回バックアップ（push しない）
./push_backup.sh [--dry-run]       # GitHub へ push（常に手動）
./cron_monitor.sh                  # ログ・GitHub 同期状態（cron 欄は今いるノードのみ）
./prepare.sh                       # 今いるノードの cron を止め、stale lock を消す
```

## ファイル

| ファイル | 役割 |
|---|---|
| `backup_param.sh` | rsync → バックアップ先で commit（push しない） |
| `push_backup.sh` | バックアップ先を GitHub へ push |
| `cron_start.sh` / `cron_stop.sh` | cron の登録・削除（今いるノードのみ） |
| `cron_monitor.sh` | 状態表示（cron 欄は今いるノードのみ） |
| `prepare.sh` | 今いるノードの cron 停止と stale lock 削除 |
| `config.env` | ローカル設定（`config.example.env` が雛形） |
| `.discord_webhook` | Discord 通知用 webhook URL（rsync・push しない） |
| `discord_status.py` | Discord の固定メッセージ 2 件を更新 |
| `backup.gitignore` | バックアップ先用 .gitignore のテンプレート |
