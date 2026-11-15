# 筆電直連 Android TV 安裝規格書（給 ctl-laptop 上的 AI 執行）

2026-11-15 · 範圍：只在家裡 Wi‑Fi 使用，不改 Tailscale、ACL、路由器

## 1. 目標

讓筆電 ctl-laptop 在**家裡 Wi‑Fi** 底下，雙擊 bat 就能直接用 scrcpy 看到並操作 Android TV，不經過 ctl-pc。

```
筆電 ctl-laptop ──家裡 Wi‑Fi（區網 ADB, tcp 5555）──▶ Android TV
（在外面時不適用：照舊 iPhone/筆電 → Tailscale → RustDesk 連 ctl-pc → 雙擊 bat）
```

## 2. 背景（AI 先讀）

- 整套系統的說明在同資料夾的 `setup-guide.md`，第 5 節是 Android TV。
- TV 不在 Tailscale 內；ADB 只在家裡區網可達。這份規格**不得**新增子網路路由、修改 Tailscale ACL、在路由器開 port。
- bat 檔放在本資料夾（OneDrive 同步，ctl-pc 與筆電共用），已寫成自動尋找 winget 安裝的 scrcpy，任何版本、任何 Windows 使用者都適用，**不需要改路徑**。
- 現有電視：

| 名稱 | IP | bat |
| --- | --- | --- |
| TV #1（AI PONT，Android 11） | 192.168.1.50 | `tv1.bat`（ctl-pc、筆電都已授權，2026-11-15） |
| 客廳 BenQ（AI PONT，Android 11） | 192.168.1.51 | `tv2.bat`（筆電、ctl-pc 都已授權，2026-11-15） |
| Sony KD-43X7000F | 192.168.1.52 | 不適用：Linux 系統、沒有 ADB，已排除 |
| 其他電視 | — | 每台一個 bat，見第 4 節第 5 步 |

## 3. 前提（AI 執行前確認）

- [ ] 筆電連的是**家裡 Wi‑Fi**（對要設定的那台 TV 跑 `Test-Connection <TV IP> -Count 1 -Quiet` 要是 True；False 就停下來請使用者確認 TV 已開機、筆電在家）
- [ ] TV 已開機，且開發人員選項的 USB 偵錯／網路偵錯是開啟的
- [ ] TV 前面**有人**可以按「允許」

## 4. 安裝步驟

1. 安裝 scrcpy（內含 adb）：
   ```powershell
   winget install --id Genymobile.scrcpy -e --accept-source-agreements --accept-package-agreements
   ```
2. 找到 adb（不要寫死版本）：
   ```powershell
   $sc = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Genymobile.scrcpy_*\scrcpy-win64-*" -Directory | Select-Object -Last 1).FullName
   & "$sc\adb.exe" version
   ```
3. 授權（每台 TV 對每台電腦各一次）：
   ```powershell
   & "$sc\adb.exe" connect <TV IP>:5555
   ```
   - 第一次會回 `failed to authenticate` 或 `unauthorized`，這是正常的：請使用者到 TV 前**勾選「一律允許這部電腦」→ 允許**
   - 使用者按完後再跑一次 `connect`，然後 `& "$sc\adb.exe" devices`，該 TV 狀態要是 `device`
4. 測試：雙擊該 TV 的 bat（見第 2 節表格），要出現對應標題的視窗，滑鼠與方向鍵能操作 TV。測完關掉視窗。
5. 其他電視（若使用者給了 IP 與名稱）：
   - 先看本資料夾是否已有該 TV 的 bat；**有就直接用，不要重做**
   - 沒有才建立：複製 `tv1.bat` 內容，只改 `set TV=` 那行的 IP 與 `--window-title` 的英文名稱，存成新檔名（檔名可中文）
   - 每台 TV 都要做第 3、4 步授權與測試

## 5. 硬性規則

- **bat 檔一律用 PowerShell 寫成 CRLF + 純 ASCII**（內容不可有中文，檔名可以）。LF 或 UTF-8 中文會讓雙擊完全沒反應。寫完一定要雙擊或 `Start-Process` 實測。寫法：
  ```powershell
  [IO.File]::WriteAllText($path, ($lines -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
  ```
- 不刪除、不移動、不重新命名任何檔案（使用者規則）；需要清理就列出路徑請使用者自己處理
- 既有的 bat 只讀不改（只能複製成新檔）；不動 RustDesk、防火牆、Tailscale；不改 TV 本身的設定（主畫面、App 等），要改先問使用者
- 同時只能開一個連同一台 TV 的 scrcpy 視窗

## 6. 驗收

| 檢查 | 預期 |
| --- | --- |
| `adb devices` | 每台 TV 都是 `device` |
| 雙擊 bat | 出現 TV 視窗，可操作 |
| TV 重開機後再雙擊 | 仍可連（不需再授權） |

## 7. 回報給使用者

- 安裝的 scrcpy 版本、授權成功的 TV 清單（名稱、IP）、新建的 bat 檔名
- 失敗項目與錯誤訊息原文
- 完成後提醒使用者把「筆電可在家直連 TV」更新進 `setup-guide.md` 第 5 節（或請 ctl-pc 上的 AI 更新）

## 8. 常見問題

| 狀況 | 原因／處理 |
| --- | --- |
| `failed to authenticate` / `unauthorized` | TV 還沒按允許，請使用者到 TV 前按 |
| `cannot connect` / ping 不通 | TV 沒開機、筆電不在家裡 Wi‑Fi、或 TV 的網路偵錯被關掉（部分 TV 重開機會關） |
| 雙擊 bat 沒反應 | bat 不是 CRLF ASCII，照第 5 節重寫 |
| 畫面黑的 | 正在播 Netflix 等 DRM 內容，或 TV 切到 HDMI 訊號源；退回 TV 首頁 |
| bat 顯示 scrcpy not found | 第 4 步第 1 項沒裝成功，重跑 winget |
