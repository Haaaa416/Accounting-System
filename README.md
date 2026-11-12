# 記帳本 Ledger

個人記帳 App。用 Flutter + drift（SQLite）開發，資料只存在本機，一份程式碼同時支援 Web、Android 和 iOS。介面走深色質感風格，也可以切換成淺色模式。

## 功能
- **明細**：依月份顯示收支，同一天的紀錄放在一起，往左滑可以刪除
- **統計**：分類圓餅圖、近六個月的收支長條圖
- **帳戶**：分開記錄現金、銀行、信用卡，各自計算餘額，並顯示淨資產
- **欠款**：記錄別人欠我／我欠別人，依人名分組，還清後打勾
- **預算**：可以設定每月總預算和各分類預算，超支時首頁會提醒
- **固定收支**：房租、訂閱、薪水這類每月固定的項目，到期會自動記帳
- **搜尋／篩選**：用備註、分類、帳戶或金額搜尋所有紀錄
- **分類圖示和顏色**：每個分類、每個帳戶都可以自訂
- **備份**：可以匯出／匯入 CSV（用 Excel 開啟），也可以把全部資料備份成 JSON 再還原

## 建立專案

```bash
flutter create --platforms=web,android,ios --project-name ledger .
flutter pub add drift drift_flutter fl_chart web
flutter pub add flutter_localizations --sdk=flutter
flutter pub add dev:drift_dev dev:build_runner
dart run build_runner build --delete-conflicting-outputs
```

只要修改了 `lib/data/database.dart`，就要重跑最後一行。

### Web 版需要的額外檔案
`web/` 資料夾裡要有 `sqlite3.wasm` 和 `drift_worker.js`。下載位置：
- https://github.com/simolus3/sqlite3.dart/releases
- https://github.com/simolus3/drift/releases

## 執行

```bash
# 網頁版：之後用平常的瀏覽器開 http://localhost:8080
flutter run -d web-server --web-port 8080

# 手機或模擬器
flutter run
```

用 `flutter run -d chrome` 開的 Chrome 每次都是暫時的設定檔，關掉之後資料就會消失，所以網頁版請用上面的 `web-server` 方式執行。

## 部署到 GitHub Pages
1. 把專案 push 到 GitHub 的 `main` 分支
2. 到 repo 的 Settings → Pages → Source，選擇 **GitHub Actions**
3. 之後每次 push 都會自動部署，網址是 `https://<帳號>.github.io/<repo 名稱>/`

## 資料庫版本
| 版本 | 內容 |
|---|---|
| v1 | 帳戶、分類圖示／顏色／預算、固定收支、設定 |

舊版本的資料庫會自動升級，原本的紀錄會歸到「現金」帳戶。

## 檔案結構
```
lib/
  main.dart            啟動、主題、語系
  app_state.dart       共用的資料庫和主題設定
  theme.dart           深色／淺色主題
  data/database.dart   資料表、升級步驟、查詢
  data/backup.dart     CSV 和 JSON 的匯出、匯入
  widgets/common.dart  共用元件（圖示、金額、選擇器、對話框）
  pages/               各個頁面
  utils/               格式化、圖示清單、下載和選檔
```
