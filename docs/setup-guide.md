# 家用遠端連線設定清單（Tailscale + RustDesk）


## 1. 總覽

所有遠端連線只走 Tailscale，RustDesk 只用「直接 IP + 永久密碼」，不經 RustDesk 公共伺服器，也不在路由器開任何 port。唯一例外是家人的 iPad / iPhone，只能用 FaceTime。

### 架構圖

```
 ┌──────────────────────────────── 你的設備（不標 tag，彼此可互連）────────────────────────────────┐
 │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐              │
 │  │ iPhone       │   │ iPad         │   │ 你的筆電      │◀─▶│ 桌電 pc-main（常開）  │              │
 │  │ 只連出        │   │ 只連出        │   │ 可連出、可被連 │   │ 可連出、可被連、TV 跳板│              │
 │  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘   └──────────┬───────────┘              │
 └─────────┼──────────────────┼──────────────────┼──────────────────────┼──────────────────────────┘
           │        Tailscale 加密通道（只允許「你的設備 → 家裡設備」）          │ 區網 ADB / scrcpy
           ▼                                                             ▼
 ┌──────────────────── 家裡設備（tag:home，彼此不通、不能連出）─────────────┐   ┌─────────────────┐
 │  ┌──────────────┐   ┌──────────────┐   ┌───────────────────┐          │   │ Android TV       │
 │  │ 家人電腦 A    │ ✕ │ 家人電腦 B    │ ✕ │ 家人 Android 手機  │          │   │ 不在 Tailscale 內│
 │  └──────────────┘   └──────────────┘   └───────────────────┘          │   └─────────────────┘
 └──────────────────────────────────────────────────────────────────────┘

 你的 iPhone ┄┄ FaceTime 分享螢幕（不走 Tailscale）┄┄▶ 家人 iPad / iPhone
```

| 設備 | 角色 | 遠端方式 | 需要對方做什麼 |
| --- | --- | --- | --- |
| 你的 iPhone / iPad | 你的設備（只連出） | Tailscale + RustDesk | — |
| 你的筆電 | 你的設備（可連出、可被你的設備連） | Tailscale + RustDesk | 不用（要開機、未睡眠） |
| 桌電 pc-main（常開） | 你的設備（可連出、可被你的設備連、TV 跳板） | Tailscale + RustDesk | 不用 |
| 家人的電腦（需遠端的） | 家裡設備 `tag:home` | Tailscale + RustDesk | 不用（要開機、未睡眠） |
| 家人 Android 手機（Pixel / Samsung / vivo） | 家裡設備 `tag:home` | Tailscale + RustDesk | 開 Tailscale 與 RustDesk，按「立即開始」 |
| Android TV | 家裡設備（不在 Tailscale） | 先連 pc-main，再用 scrcpy（ADB） | 不用（重開機後若網路偵錯被關，要請家人開） |
| 家人 iPad / iPhone | 不在 Tailscale | FaceTime 分享螢幕 | 打給你並分享螢幕、同意遠端控制 |
| 不需要遠端的電腦 | 不加入 | 什麼都不裝 | — |

設備分兩級：**你的設備**（你名下、不標 tag）彼此可互連，也能連家裡設備；**家裡設備**（標 `tag:home`）只能被你的設備連，不能連任何設備，彼此也不通。所有設備都不設定金鑰到期。

### 目前進度

截至 2026-11-15：你的四台設備（iPhone、iPad、筆電、ctl-pc）全部完成，互連驗收通過；兩台 Android TV 安裝完成（ctl-pc 雙擊 `tv1.bat`、`tv2.bat` 即可操作；筆電在家可直連兩台電視），家人電腦 pc-home 完成，ctl-pc BIOS 已設定。Sony KD-43X7000F 不是 Android TV，已排除。家人 Android 手機 family-phone 完成（iPhone 需經 ctl-pc 轉連）。剩下：教家人照 PDF 操作一次；Tailnet Lock 標記為之後再做；其他家人電腦暫不加入，家人 iPad / iPhone 不處理。

| 項目 | 狀態 | 備註 |
| --- | --- | --- |
| Tailscale 帳號與後台 | 完成 | MagicDNS、Device approval、兩條 ACL 都已套用；Tailnet Lock 留到最後 |
| 你的 iPhone（ctl-iphone） | 完成 | 操作端；已驗證筆電、ctl-pc 都連不到它 |
| 你的筆電（ctl-laptop） | 完成並上鎖 | 2FA、白名單、ID 伺服器、防火牆、BitLocker 都已確認；電源維持接電源 15 分鐘睡眠（你的決定） |
| 桌電 ctl-pc | 完成並上鎖 | 已從 tag:home 改為你的設備；scrcpy 5.0.1 已裝（winget）；BIOS 斷電回復後電源狀態＝上次狀態（ErP 關閉）|
| 你的 iPad（ctl-ipad） | 完成 | IP 100.64.0.12；已加進 ctl-pc、筆電的 RustDesk 白名單與防火牆；行動網路驗收通過 |
| 家人的電腦 pc-home（DESKTOP-XXXXXXX） | 完成 | IP 100.64.0.21；用 QR code 登入加入，已帶 `tag:home`、Expiry disabled；防火牆 4 條規則都已鎖白名單；反向測試通過；ctl-pc → pc-home 21118 可通 |
| 其他家人的電腦 | 暫不加入 | 之後有需要再加，照 pc-home 流程（見「電腦設定」） |
| 家人 Android 手機 family-phone（Pixel 8a） | 完成（iPhone 直連除外） | IP 100.64.0.22；tag:home、Expiry disabled；RustDesk 白名單、2FA、IP 直接連線、固定密碼（2026-11-15）、輸入控制（無障礙）已開、ID 伺服器 127.0.0.1、「管理未使用的應用程式」關閉（RustDesk 與 Tailscale）、通知開啟（2026-11-15 你確認全部完成）；電腦（筆電、ctl-pc）連線有畫面；iPhone 直連卡「等待畫面傳輸」；iPhone 經 ctl-pc 雙擊 `phone-jump.bat` 轉連可行（ctl-pc 的 RustDesk 主視窗在遠端畫面中是白的、點不到，用 bat 繞過）；iPad 未測 |
| Android TV #1（AI PONT，Android 11） | 完成 | 固定 IP 192.168.1.50、ADB 已授權、`tv1.bat` 實測可開；USB／網路偵錯維持開啟（你的決定）；重開機後重測、iPhone 行動網路完整流程都已通過 |
| 其他 Android TV | 無（2026-11-15 你確認電視都處理完） | 之後新增 TV 照第 5 節做：路由器綁固定 IP、開偵錯、ctl-pc 授權；各自複製一份 bat 改 `set TV=` 那行與檔名 |
| 客廳 BenQ（AI PONT，Android 11） | 完成 | 固定 IP 192.168.1.51、筆電與 ctl-pc 都已授權、`tv2.bat` 筆電實測可開、重開機後 ADB 仍可連；USB 偵錯維持開啟 |
| Sony KD-43X7000F（192.168.1.52） | 不處理 | 2026-11-15 確認是 Sony Linux 系統、不是 Android TV，沒有 ADB，bat／scrcpy 不適用；你的決定：排除在遠端清單外（推薦列可在電視主畫面用遙控器關閉） |
| 家人 iPad / iPhone | 不處理 | 你的決定：不需要遠端；之後要用再照第 7 節 FaceTime |

接下來的順序：

- [x] 你的 iPad：安裝 Tailscale 與 RustDesk、改名 `ctl-ipad`、Disable key expiry（2026-11-14，IP 100.64.0.12）
- [x] ctl-pc 防火牆「RustDesk Service」加入 iPad IP
- [x] ctl-pc RustDesk 白名單加入 100.64.0.12
- [x] 筆電：RustDesk 白名單與防火牆加入 100.64.0.12
- [x] iPad 用行動網路連 ctl-pc 與筆電驗收
- [x] 家人的電腦 pc-home（2026-11-14，IP 100.64.0.21）
- 其他家人的電腦：暫不加入，之後有需要再照 pc-home 流程做
- [x] 家人 Android 手機 family-phone（2026-11-15，IP 100.64.0.22）；給家人的圖文說明：`family-phone-guide.pdf`
- [x] family-phone 收尾：ID 伺服器 127.0.0.1、「管理未使用的應用程式」關閉、通知開啟（2026-11-15）
- [ ] 教家人照 `family-phone-guide.pdf` 自己操作一次
- 歡唱機金嗓 SS700：接在 Sony KD-43X7000F（非 Android TV、沒有 ADB），無法透過 TV 的 scrcpy 看畫面，2026-11-15 標記為做不到。若之後要遠端看／操作，只能另外考慮：SS700 本身的開發人員選項、KVM 盒、擷取卡＋紅外線（你還在考慮）
- [x] Android TV：ctl-pc 裝 scrcpy、TV 開網路偵錯、ADB 授權（2026-11-14）
- [x] Android TV #1：`tv1.bat` 雙擊實測可開（2026-11-14）
- [x] 選做驗收：TV #1 重開機後再雙擊一次、用 iPhone 行動網路走一次完整流程
- [x] 其他 Android TV：電視都處理完（2026-11-15，你確認）
- [x] TV #1：筆電授權（2026-11-15，adb devices 顯示 device）
- [x] Sony KD-43X7000F：不是 Android TV，排除（2026-11-15）
- [x] 客廳 BenQ（192.168.1.51）：筆電授權、`tv2.bat` 實測、換主畫面、重開機驗證（2026-11-15）
- [x] 客廳 BenQ：ctl-pc 雙擊 `tv2.bat`，在電視前按允許授權；路由器綁 192.168.1.51（2026-11-15，使用者回報完成）
- [x] 筆電裝 scrcpy 5.0.1（winget，2026-11-15）；TV #1、客廳 BenQ 都已授權
- 家人 iPad / iPhone：不處理（你的決定）
- [x] ctl-pc 的 BIOS 斷電回復後電源狀態設為「上次狀態」（2026-11-15）
- [ ] 之後再做：啟用 Tailnet Lock（2026-11-15 你決定延後）。做之前要準備：簽章設備用 ctl-pc＋筆電兩台；停用密鑰存在加密保存庫（與 Tailscale 登入帳號不同的雲端）＋紙本一份，不寫進本文件。以後加設備多一步：在 ctl-pc 或筆電跑後台顯示的簽名指令
- [ ] 選做：家裡電腦之間的網路芳鄰（只限區網）
- [x] 2026-11 每月檢查完成：設備清單、Configuration logs、ctl-pc、筆電、pc-home 的防火牆與 RustDesk 連線來源都正常（ctl-pc 已補回 Inbound 規則）
- [x] 每月檢查自動排程：ctl-pc、筆電已設定（工作排程器 `HomeRemote\MonthlyCheck`，每月 1 號 10:00、錯過就下次登入補跑；有問題才跳出視窗；結果存在本資料夾 `logs\<電腦名稱>-<年-月>.txt`，經 OneDrive 同步）
- [x] 每月檢查自動排程：pc-home（2026-11-15；以 SYSTEM 執行、只寫記錄不跳視窗；腳本與 `register-monthly-tasks.ps1 -Mode System` 放 OneDrive 的 `share_folder\遠端操控設定`，pc-home 上的帳號是 <family-user>，路徑不是 `C:\Users\User`；記錄在同資料夾 `logs\`，同步回 ctl-pc 可直接讀；首次結果全部通過）
- [x] 每月 2 號總結：ctl-pc 排程 `HomeRemote\MonthlySummary`（`monthly-summary.ps1`，每月 2 號 10:00，錯過就補跑）確認三台都有本月記錄且最後一次通過；缺記錄或有問題就在 ctl-pc 跳視窗，結果附加到 `logs\summary-<年-月>.txt`（2026-11-15 實測：正常與缺記錄兩種情況都正確）
- [ ] 每月：看到 ctl-pc 沒跳視窗就代表三台都通過；仍要到 Tailscale 後台看 Configuration logs（最近 30 天）

## 2. Tailscale 帳號與後台

Tailscale 帳號是整套系統的萬能鑰匙，先把它鎖緊再裝設備。

- [ ] 登入用的 Google / Microsoft 帳號開兩步驟驗證（最好用 Passkey 或實體金鑰）
- [ ] DNS → 開啟 MagicDNS（用 `pc-main` 這類名稱連線）
- [ ] Settings → 開啟 Device approval（新設備要手動核准）
- [ ] 最後一步：所有設備都加入後，在一台已登入的設備用命令列啟用 Tailnet Lock（`tailscale lock init`），救援金鑰另外保管
- [ ] 家裡設備（家人的電腦、家人 Android 手機）標上 `tag:home`（會自動停用金鑰到期）
- [ ] 你的設備（iPhone、iPad、筆電、pc-main）不標 tag，逐台在 Machines → ⋯ → Disable key expiry
- [ ] Access controls 換成下面的 ACL（人在家時再套用，套完確認自己還連得上）

名詞說明：

- **key expiry（金鑰到期）**：設備登入 Tailscale 的憑證預設約 180 天到期，到期後會斷線，要有人在該設備前重新登入。這套設備全部停用到期；代價是你的設備遺失時憑證不會自己失效，要馬上到後台移除。
- **tag:home**：把設備標成「家裡設備」。ACL 用它規定「只有你的設備能連進來」；家裡設備彼此不通，也不能反過來連你的設備。你的設備一定不能標 tag，標了就不再算「你名下的設備」，會失去連出去的權限。

ACL：第一條讓你的設備連家裡設備；第二條讓你的設備彼此互連。沒有任何一條讓家裡設備連出去。

| 從 ↓ 連到 → | 你的設備 | 家裡設備 |
| --- | --- | --- |
| 你的設備 | 可以 | 可以 |
| 家裡設備 | 不行 | 不行 |

```json
{
  "tagOwners": { "tag:home": ["autogroup:admin"] },
  "grants": [
    { "src": ["autogroup:admin"],  "dst": ["tag:home"],       "ip": ["tcp:21118"] },
    { "src": ["autogroup:member"], "dst": ["autogroup:self"], "ip": ["tcp:21118"] }
  ]
}
```

設備遺失或送修前：到 Tailscale 後台移除該設備。

## 3. 你的設備：iPhone / iPad / 筆電 / pc-main

你的設備不標 tag，屬於你個人，彼此可互連，也能連家裡設備。iPhone / iPad 只能連出去（iOS 不能被控制）；筆電與 pc-main 可連出、也可被你的其他設備連。

- [ ] 安裝 Tailscale（iPhone / iPad 從 App Store，電腦從官網），用同一帳號登入，**不標 tag**
- [ ] 後台逐台 Disable key expiry
- [ ] iPhone / iPad：安裝 RustDesk 即可，不必開直接 IP 存取或設密碼
- [ ] 筆電與 pc-main：另外照下一節「電腦設定」完成 RustDesk 被連線的設定
- [ ] RustDesk 用 IP 連線，連過一次後在最近連線清單重新命名、加入最愛；不要輸入沒有「.」的名稱（會被當成公共伺服器上的 ID）
- [ ] 確認你的設備都有螢幕鎖（Face ID / Windows Hello），因為最愛清單可能存有密碼

使用小技巧：iPhone 操作 Windows 時用「滑鼠模式」；要看 TV 的 scrcpy 視窗，用 iPad 或筆電比 iPhone 清楚很多。

你的設備 IP 對照表（白名單用）：Tailscale IP 在設備加入後分配，之後固定不變；在後台 Machines 頁可以看到。

| 你的設備 | Tailscale IP |
| --- | --- |
| iPhone（ctl-iphone） | 100.64.0.11 |
| iPad（ctl-ipad） | 100.64.0.12 |
| 筆電（ctl-laptop） | 100.64.0.13 |
| 桌電 pc-main（ctl-pc） | 100.64.0.10 |

白名單怎麼填（RustDesk IP 白名單與 Windows 防火牆都用同一份）：

| 設定在哪台 | 白名單填哪些 IP |
| --- | --- |
| pc-main | iPhone、iPad、筆電 |
| 你的筆電 | iPhone、iPad、pc-main |
| 家裡設備（家人的電腦、手機） | iPhone、iPad、筆電、pc-main |

家裡設備的白名單不填彼此的 IP，所以就算在家裡區網直接連，家人的電腦之間也連不上。之後新增或更換你的設備，要回來更新每台的白名單。

## 4. 電腦設定（pc-main、你的筆電、家人的電腦）

這節是所有要被遠端的電腦：桌電 pc-main（常開、TV 跳板）、你的筆電、需要遠端的家人電腦。不需要遠端的電腦不用做任何設定。

每台電腦：

- [ ] 安裝 Tailscale 並登入：家人的電腦在後台標 `tag:home`；pc-main 與你的筆電**不標 tag**，改手動 Disable key expiry
- [ ] Tailscale 系統匣圖示 → 開啟 **Run unattended**（沒登入 Windows 也會連線，重開機後停在登入畫面也連得到）
- [ ] 從 rustdesk.com 或官方 GitHub 下載 RustDesk，選「安裝」；裝完在系統管理員終端機確認 `Get-Service RustDesk` 是 Running，沒有就執行 `& "C:\Program Files\RustDesk\RustDesk.exe" --install-service`（沒有服務就不會監聽 21118）
- [ ] RustDesk 安全 → 開啟「啟用 IP 直接存取」（port 21118）、勾選「拒絕區域網路探索」
- [ ] RustDesk 密碼 → 選「使用固定密碼」，16 碼以上隨機，每台不同；接受方式可維持「允許輸入密碼或點選接受」
- [ ] RustDesk 安全 → 「只允許白名單上的 IP 進行連線」，依上一節白名單表填寫（不要填整段 `100.64.0.0/10`）
- [ ] RustDesk 2FA → 啟用二步驟驗證，用手機的驗證器 App 掃 QR code；連線時除了密碼還要輸入 6 位數驗證碼。每台各有一組，驗證器裡用設備名稱命名（例：RustDesk ctl-pc）；驗證器要開雲端備份，否則手機遺失會被鎖在所有電腦外面
- [ ] RustDesk 網路 → ID 伺服器填 `127.0.0.1`（底部會一直顯示「正在連線到 RustDesk 網路...」，這是正常的：故意不連公共伺服器；已實測直接 IP 照常可連）
- [ ] Windows 防火牆：RustDesk（21118）的輸入規則，遠端 IP 填同一份白名單。系統管理員 PowerShell：`Get-NetFirewallRule -DisplayName "RustDesk*" | Set-NetFirewallRule -EdgeTraversalPolicy Block -RemoteAddress <白名單 IP,逗號分隔>`，再用 `Get-NetFirewallRule -DisplayName "RustDesk*" | Get-NetFirewallAddressFilter` 確認**每一條**都不是 Any。`-EdgeTraversalPolicy Block` 不能省：Windows 跳「允許存取」視窗自動建的規則，不加這個參數就改不了 IP
- [ ] Windows 帳號設密碼或 PIN、閒置自動鎖定、不設自動登入（連進去先看到登入畫面，是第二道門）
- [ ] Windows 自動更新保持開啟

家人的電腦加入 Tailscale（建議，pc-home 用這個）：QR code 登入，只帶 iPhone 就能做，不在家人電腦上輸入你的帳密。

1. 家人電腦：安裝 Tailscale 但不要按 Log in；系統管理員終端機執行 `& "C:\Program Files\Tailscale\tailscale.exe" up --unattended --advertise-tags=tag:home --qr`
2. iPhone 相機掃終端機上的 QR code，在 iPhone 上登入你的帳號
3. iPhone Safari 開 Tailscale 後台：Approve、改名、確認已帶 `tag:home` 且 Expiry disabled、記下 IP
4. 家人電腦的 Tailscale 系統匣顯示你的 email 是正常的，以後台的 tag 為準

備案：用一次性 auth key，不在家人電腦上輸入你的 Google 帳密，而且會自動帶上 `tag:home`。

1. 你的筆電：Tailscale 後台 → Settings → Keys → Generate auth key；Reusable 關、Expiration 1 天、Pre-approved 關、Tags 選 `tag:home`；複製 `tskey-auth-...`（只顯示一次，不要存檔）
2. 家人電腦：安裝 Tailscale 但不要按 Log in；系統管理員終端機執行 `& "C:\Program Files\Tailscale\tailscale.exe" up --auth-key=tskey-auth-... --unattended`
3. 你的筆電：後台 Approve、改名（例：`nb-dad`）、確認已帶 `tag:home` 且 Expiry disabled、記下 IP
4. 驗收時加做反向測試：在家人電腦執行 `Test-NetConnection 100.64.0.13 -Port 21118` 與 `Test-NetConnection 100.64.0.10 -Port 21118`，兩個都要是 False

桌電（pc-main）額外：

- [ ] 從 `tag:home` 改成你的設備：後台 Machines → ⋯ → Edit ACL tags，移除 `tag:home`。若後台不讓你移除，就在 pc-main 的 Tailscale 登出、再用你的帳號登入（會斷線，要在家或用別的遠端方式操作）。完成後 Disable key expiry，並重新確認 IP
- [ ] 關掉睡眠（它關機，TV 就連不到）
- [x] BIOS：「Restore on AC Power Loss」（中文介面：進階 → 高級電源管理 → 斷電回復後電源狀態）設為「上次狀態」，ErP 就緒要關閉（2026-11-15 完成；想要有電就一定開機則改「開啟」）。ctl-pc 是 ASUS 主機板：開機狂按 Del（或 Windows 設定 → 系統 → 復原 → 進階啟動 → 疑難排解 → 進階選項 → UEFI 韌體設定）→ F7 進 Advanced Mode → Advanced → APM Configuration → Restore AC Power Loss → 上次狀態或 Power On → F10 儲存
- [ ] 選做：BIOS 與網卡開 Wake-on-LAN；要從外面喚醒，需要路由器支援遠端 WoL
- [x] 安裝 scrcpy（內含 adb）：`winget install --id Genymobile.scrcpy -e`
- [x] 「連 TV」捷徑：本資料夾的 `tv1.bat`（先 `adb connect` 再開 scrcpy；TV IP 寫在檔案開頭，改 IP 時要改；scrcpy 路徑會自動尋找，升級或換電腦都不用改）。筆電在家直連 TV：見 `laptop-tv-spec.md`

筆電（你的或家人的）額外：

- [ ] 接電源時不睡眠、蓋上螢幕不動作
- [ ] 開 BitLocker
- 不設喚醒：筆電關機或睡眠時連不到是正常的
- 建議命名規則：你的設備用 `ctl-` 開頭（pc-main 例外），家人的電腦用 `nb-` 或 `pc-` 開頭（例：`nb-dad`），在 Machines 清單一眼分得出來

### 開機後要重新開什麼？

照上面設好，電腦開機後什麼都不用開：Tailscale（Run unattended）與 RustDesk（服務）在登入 Windows 前就自動啟動。

| 設備 | 開機後自動啟動 | 仍要人做的事 |
| --- | --- | --- |
| 所有電腦 | Tailscale、RustDesk 服務 | 無（沒開 Run unattended 的話，要登入 Windows 後 Tailscale 才連線） |
| Android 手機 | 不自動（平常不連線） | 照 SOP 開 Tailscale 與 RustDesk，按「立即開始」 |
| Android TV | ADB（若網路偵錯有保留） | 部分機型要重開網路偵錯 |
| 你的 iPhone / iPad | — | 使用前打開 Tailscale |

確認方式：電腦重開機後停在登入畫面，從 iPhone 用行動網路連得上就對了。

## 5. Android TV（ADB + scrcpy）

TV 不裝 Tailscale、不裝 RustDesk，由 pc-main 在家裡區網用 ADB 控制：ADB 授權一次就永久有效，scrcpy 支援方向鍵、返回、首頁。

一次性設定（在家做）：

以下打勾的是 TV #1（AI PONT，`192.168.1.50`）；其他 TV 每台都要從頭做一次，bat 複製一份改 IP 與檔名。

- [x] 路由器幫 TV 設 DHCP 固定 IP：`192.168.1.50`
- [x] TV：設定 → 關於 → 連按版本號 7 次，開啟開發者選項
- [x] TV：開啟 USB 偵錯與網路偵錯
- [x] pc-main 執行 `adb connect 192.168.1.50:5555`，TV 跳出授權時勾「一律允許這台電腦」→ 允許
- [x] 測試 `scrcpy -s 192.168.1.50:5555` 能看到並操作 TV（滑鼠右鍵＝返回、中鍵＝首頁）
- [ ] TV 重開機後再測一次，確認網路偵錯沒被關掉

遠端使用流程：

1. iPhone 開 Tailscale → 開 RustDesk → 連 pc-main
2. 在 pc-main 雙擊本資料夾的 `tv1.bat`，TV 畫面以視窗出現（同時只能開一個 TV 視窗）
3. 視窗最大化，用滑鼠點選、方向鍵移動

TV 的 USB 偵錯、網路偵錯要一直開著，也不要按「撤銷 USB 偵錯授權」，否則要在 TV 前重新授權 ctl-pc。port 5555 只有家裡區網連得到，且只認已授權的電腦；跟家人約好：TV 跳出「允許 USB 偵錯嗎？」一律按拒絕，除非是你要求的。

注意：播 Netflix 等影音內容時畫面會是黑的（DRM），請家人先退回首頁。部分 TV 重開機會關掉網路偵錯，若如此，要請家人重開，或改用 USB 線接 pc-main。

## 6. Android 手機（Pixel / Samsung / vivo）

手機直接加入 Tailscale；最容易出問題的是省電機制把 App 關掉，不是權限。

每支手機：

- [ ] 安裝 Tailscale（Play 商店），登入、後台標 `tag:home`
- [ ] Tailscale **不開**「一律開啟的 VPN」：平常關著，要請你幫忙時才開（見下方 SOP）
- [ ] 安裝 RustDesk（只從官方 GitHub 或 F-Droid）；Samsung 裝完後把「自動封鎖程式」開回來
- [ ] RustDesk：直接 IP 存取、IP 白名單填你的設備全部 IP（iPhone、iPad、筆電、pc-main）、永久密碼、ID 伺服器 `127.0.0.1`
- [ ] 允許受限制的設定 → 開 RustDesk 的無障礙權限（遠端操作用）
- [ ] 開完無障礙後，逐一打開家人常用的銀行、支付 App 確認能正常使用；若被擋，這支手機就關掉無障礙，改成你只看畫面、家人自己點
- [ ] Tailscale、RustDesk 都設成不限制電池用量（避免連線中被系統關掉）
- [ ] 把 Tailscale 與 RustDesk 圖示放在主畫面同一頁，家人好找

家人要請你遠端時的 SOP（印出來或存在他們手機）：

1. 打開 **Tailscale** → 按中間的開關，變成「Connected」（第一次會跳「連線要求」，按確定）
2. 打開 **RustDesk** → 下方點「**螢幕分享**」→ 按「**啟動服務**」→ 跳出「開始錄製或投放」時選「**整個螢幕**」→ 按「**立即開始**」
3. 打電話給你，說「我開好了」；**手機保持亮著、不要鎖螢幕**（螢幕一鎖錄製就會自己停）
4. 幫忙完：RustDesk「螢幕分享」→ 按「**停止服務**」；再回 Tailscale 把開關關掉（平常兩個都關著，省電）

你這邊：用**電腦**連（筆電或 ctl-pc），先開 Tailscale，再從 RustDesk 最愛清單點家人手機（用 IP 連線）。人在外面只有 iPhone 時（2026-11-15 實測可行）：iPhone → RustDesk 連 ctl-pc → 在 ctl-pc 雙擊本資料夾的 `phone-jump.bat`（直接開 RustDesk 連 `100.64.0.22` 的連線視窗）→ 輸入家人手機的密碼與 2FA。不要在遠端畫面裡點 ctl-pc 的 RustDesk 主視窗：它在遠端畫面中是白的、點不到，所以才用 bat 繞過。給家人看的操作說明：本資料夾 `family-phone-guide.pdf`。

已知限制（2026-11-15 實測）：iPhone 直接連 Pixel 會卡在「已連線，等待畫面傳輸」，改編解碼器、關硬體編碼、Pixel 螢幕保持亮著都無效；電腦連同一支 Pixel 正常。Pixel 的「啟用硬體編解碼器」維持開啟。RustDesk 服務沒啟動時 port 21118 會關閉，連線直接失敗。

各品牌路徑（找不到就在設定裡搜尋「無障礙」或「電池」）：

| 項目 | Pixel | Samsung | vivo |
| --- | --- | --- | --- |
| 安裝被擋 | 不會 | 設定 → 安全性與隱私 → 自動封鎖程式，暫時關掉、裝完再開 | 可能要輸入 vivo 帳號密碼 |
| 允許受限制的設定 | App 資訊 → ⋮ → 允許受限制的設定 | 同 Pixel | 同 Pixel；沒有此選項就直接開無障礙 |
| 無障礙 | 設定 → 無障礙 → 已下載的應用程式 → RustDesk | 設定 → 協助工具 → 已安裝的應用程式 → RustDesk | 設定 → 捷徑與輔助功能 → 無障礙 → RustDesk |
| 省電白名單 | App 資訊 → 電池 → 不受限制 | App 資訊 → 電池 → 不受限制；另加：電池 → 背景使用限制 → 永不休眠的應用程式 | ① 電池 → 背景耗電管理 → 允許高耗電 ② 應用程式 → 自啟動 → 允許 ③ 最近使用畫面將卡片往下拉鎖定 |

限制：家人沒開 Tailscale 時，你完全連不到他的手機（這是故意的）。每次連線都要按一次「立即開始」（Android 系統規定，密碼無法跳過）。vivo 系統更新後，白名單可能被重設，要再測一次。

## 7. 家人 iPad / iPhone（FaceTime，例外）

iOS / iPadOS 不允許第三方 App 遠端控制，只能用 FaceTime；這是唯一不走 Tailscale 的連線（Apple 端對端加密，必須對方主動發起）。

- [ ] 確認家人設備與你的設備都是 iOS / iPadOS 18 以上（不到 18 只能看，不能操作）
- [ ] 教家人流程：FaceTime 打給你 → 分享螢幕 → 你按「請求遠端控制」→ 對方同意

## 8. 選用：Windows 遠端桌面（RDP）

Windows 家用版不能當 RDP 的被控端，只有 Pro 版可以；要用 RDP，該台電腦得先升級 Pro（設定 → 系統 → 啟用 → 升級 Windows 版本，付費）。不建議用 RDP Wrapper 這類破解工具：違反授權、Windows 更新後常失效，而且要修改系統檔。目前決定：先維持 RustDesk。

| | RDP（Pro 版） | RustDesk |
| --- | --- | --- |
| 適合 | 你自己遠端用自己的電腦（畫面流暢、解析度自動配合、剪貼簿互通） | 陪家人看畫面（兩邊同時看得到） |
| 遠端時本機螢幕 | 變成鎖定畫面，家人看不到你在做什麼 | 照常顯示 |
| 連線記錄 | Windows 事件檢視器有完整登入記錄 | 只有文字 log 檔 |

升級 Pro 的電腦要加開 RDP 時：

- [ ] 設定 → 系統 → 遠端桌面 → 開啟，並保留「需要網路層級驗證」
- [ ] Windows 防火牆：3389 的輸入規則，遠端 IP 填同一份白名單
- [ ] Tailscale ACL 的 `ip` 加上 `tcp:3389`
- [ ] 你的 iPhone / iPad 安裝微軟的 Windows App，筆電用內建的遠端桌面連線

## 9. 連線記錄與每月檢查

這套免費方案沒有一個集中的「誰在何時連過誰」清單，記錄分散在三個地方。

| 要查什麼 | 在哪裡看 | 備註 |
| --- | --- | --- |
| 有沒有不認得的設備、各設備最後上線時間 | Tailscale 後台 → Machines | — |
| 誰改過設定（新增設備、改 ACL、關掉保護） | Tailscale 後台 → Logs（Configuration audit logs） | 只記設定變更，不記每次連線；逐筆流量記錄是付費方案功能 |
| 每台電腦被 RustDesk 連線的時間與來源 IP | 該電腦的 RustDesk log 資料夾：`C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\log` | 已在 ctl-pc 確認：`log\server\RustDesk_rCURRENT.log`，找「Connection opened from」那行就是來源 IP。查詢：`Select-String -Path "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\log\server\*.log" -Pattern "Connection opened from" \| Select-Object -Last 20` |
| RDP 登入記錄（有開 RDP 的電腦） | 事件檢視器 → 應用程式及服務記錄檔 → Microsoft → Windows → TerminalServices-RemoteConnectionManager，事件 1149 | 含時間、帳號、來源 IP |

每月檢查（第 2～4 項由 `monthly-check.ps1` 自動完成，見下方說明；第 1 項的 Logs 仍要到網頁看）：

- 自動：工作排程器 `HomeRemote\MonthlyCheck` 每月 1 號 10:00 以系統管理員權限執行 `monthly-check.ps1 -Scheduled`；結果寫入腳本旁的 `logs\<電腦名稱>-<年-月>.txt`（同月多次附加在後），有問題才跳出視窗（pc-home 加 `-NoPopup` 只寫記錄）
- 手動：系統管理員 PowerShell 執行 `powershell -ExecutionPolicy Bypass -File <路徑>\monthly-check.ps1`
- 改完腳本要等 OneDrive 在各台同步完成再測，否則會跑到舊版（2026-11-15 筆電第一次排程就因此失敗，結果碼 1）
- 每月 2 號：ctl-pc 的 `monthly-summary.ps1` 檢查三台的本月記錄是否都在且通過（補上 pc-home 不跳視窗、某台根本沒跑的缺口）

- [ ] Tailscale Machines：只有清單內的設備，沒有多出來的
- [ ] Tailscale Logs：沒有不是你做的設定變更
- [ ] pc-main 的 RustDesk log：連線來源都在白名單內，時間都是你自己連的
- [ ] 每台被遠端的電腦：系統管理員 PowerShell 跑 `Get-NetFirewallRule -DisplayName "RustDesk*" | Get-NetFirewallAddressFilter`，**每一條**的 RemoteAddress 都只有白名單 IP（RustDesk 安裝、補裝服務、更新時可能多建一條不限 IP 的規則；Windows 只要任一條允許就放行）

## 10. 驗收、維護與家人須知

每台設備設定完，都要用行動網路實測過才算完成。

驗收（每台設備）：

- [ ] 設備重新開機（電腦、TV 不打開任何 App；Android 手機照 SOP 開 Tailscale 與 RustDesk）
- [ ] 你的 iPhone 關掉 Wi-Fi，用行動網路連線
- [ ] 確認看得到畫面、能操作
- [ ] 隔天再測一次（電腦確認省電機制沒關掉 App；手機確認家人能自己照 SOP 操作）

日常維護：

- 系統更新後（尤其 vivo、TV）重測一次
- 設備遺失、送修、淘汰 → 到 Tailscale 後台移除
- 只從官方來源更新 Tailscale、RustDesk

跟家人約好：遠端只能由家人主動打給你開始；接到自稱是你的來電或訊息要求開 VPN、遠端軟體或說出密碼，一律先掛掉再回撥你的號碼確認（詐騙常用手法）。

已知限制與待實測：

- pc-main 關機或睡眠 → TV 連不到
- 經過兩層連線看 TV 的延遲
- 影音 App 畫面為黑屏（DRM）
- 新增你的設備時，要把它的 IP 加進每台的白名單；RustDesk 更新後要確認服務仍在執行、防火牆規則沒被重設
