# home-remote-access-tailscale-rustdesk

> 不開任何對外 port、不經公共中繼伺服器，從外面遠端協助家人的電腦、手機與電視。
> A zero-open-port home remote-support setup with Tailscale + RustDesk + ADB/scrcpy.

**技術：** Tailscale（WireGuard、ACL、tags、Device approval）· RustDesk（直接 IP、IP 白名單、2FA）· ADB + scrcpy · Windows Defender 防火牆 · PowerShell · Windows Batch · Android 權限與省電管理

人在外面，家人打電話說「電腦怪怪的」「電視找不到節目」「手機不會設定」。這個專案把家裡多台不同系統的設備（Windows、Android 手機、Android TV、iOS）整合成一套**我能從外面安全協助、家人不用學新東西**的遠端支援環境，並把設計、設定步驟、驗收方式和踩過的坑整理成文件。

> 本 repo 所有 IP、主機名稱、帳號都已換成範例值；真實環境的設定與截圖不公開。

## 架構

```
 ┌──────────────── 我的設備（操作端，彼此可互連）────────────────┐
 │  iPhone   iPad   筆電   桌電 ctl-pc（常開，兼 TV 跳板）          │
 └─────┬───────────────────────────────────────────┬──────────┘
       │ Tailscale 加密通道（WireGuard）                │ 家裡區網 ADB
       │ ACL：只允許「我的設備 → 家裡設備」tcp/21118      ▼
       ▼                                         Android TV ×2
 ┌──────────── 家裡設備（tag:home，彼此不通、不能連出）────────────┐
 │  家人電腦（RustDesk）        家人 Android 手機（RustDesk）      │
 └───────────────────────────────────────────────────────────┘
```

| 設備類型 | 遠端方式 | 家人要做什麼 |
| --- | --- | --- |
| 家人電腦 | Tailscale + RustDesk（直接 IP） | 什麼都不用做（開機即可） |
| 家人 Android 手機 | Tailscale + RustDesk | 照[圖文說明](docs/family-phone-guide.pdf)開兩個 App |
| Android TV | 由常開桌電用 ADB + scrcpy 控制 | 什麼都不用做 |
| 非 Android 的電視 | 不納入（沒有 ADB） | — |

## 安全設計

由外而內每一層都要通過才連得到：

1. **不開任何對外 port**：路由器零 port forwarding，所有連線走 Tailscale。
2. **Tailscale ACL**：只開 `tcp/21118`（RustDesk 直連）；家裡設備標 `tag:home`，不能連出、彼此不通。
3. **Device approval**：新設備要在後台手動核准；家人設備用 QR code 或一次性 auth key 加入，不在家人設備上輸入我的帳密。
4. **RustDesk 不用公共伺服器**：只用「直接 IP」，ID 伺服器設成 `127.0.0.1`；IP 白名單只填我的設備。
5. **RustDesk 固定密碼 + 2FA**，每台不同。
6. **Windows 登入密碼**：連進去先看到的是登入畫面。
7. **人的那一層**：只有家人主動打給我才開；有人冒充我要求開 App 或給驗證碼，一律先掛掉回撥。

## 每月自動安全檢查

設定完不代表永遠安全：RustDesk 更新可能重建防火牆規則、設備可能被加錯、陌生來源可能連進來。所以每台被遠端的電腦每月自動自我檢查一次，結果透過 OneDrive 匯集，隔天由常開的桌電彙總：

```
每月 1 號 10:00（錯過就下次開機補跑）
 ┌ 桌電 ctl-pc  ─ monthly-check.ps1 ─┐   有問題 → 在該台跳視窗
 ├ 筆電        ─ monthly-check.ps1 ─┤   （家人電腦以 SYSTEM 執行，只寫記錄不跳窗，避免嚇到家人）
 └ 家人電腦     ─ monthly-check.ps1 ─┘
        │ 各自寫 logs\<電腦名稱>-<年-月>.txt，經 OneDrive 同步
        ▼
每月 2 號 10:00  桌電 monthly-summary.ps1
        └ 三台都有本月記錄且通過 → 安靜；缺記錄或沒通過 → 在桌電跳視窗
```

| 檢查項目 | 怎麼判斷 |
| --- | --- |
| Tailscale 設備清單 | 只能是已知的設備名稱；所有設備金鑰到期都已停用 |
| RustDesk 防火牆規則 | 一定要有 Inbound 規則；每一條的遠端 IP 都只能是我的設備 |
| RustDesk 連入記錄 | 最近 20 筆來源 IP 都要是我的設備 |

腳本全部唯讀、不改任何設定；排程用 [`scripts/register-monthly-tasks.ps1`](scripts/register-monthly-tasks.ps1) 一行建立（`-Mode User` / `System` / `Summary`）。只剩 Tailscale 後台的 Configuration logs 要每月到網頁看一眼。

## 目錄

| 路徑 | 內容 |
| --- | --- |
| [`docs/setup-guide.md`](docs/setup-guide.md) | 完整設定清單：Tailscale 後台、ACL、各類設備步驟、驗收、每月檢查（含實作進度紀錄） |
| [`docs/laptop-tv-spec.md`](docs/laptop-tv-spec.md) | 交給另一台電腦上的 AI 代理執行的安裝規格書（筆電在家直連 TV） |
| [`docs/family-phone-guide.pdf`](docs/family-phone-guide.pdf) | 給長輩看的圖文操作說明（示意版） |
| [`scripts/tv-template.bat`](scripts/tv-template.bat) | 一鍵開啟 Android TV 遠端視窗（自動尋找 scrcpy） |
| [`scripts/phone-jump-template.bat`](scripts/phone-jump-template.bat) | 從 iPhone 經桌電跳板連家人手機 |
| [`scripts/monthly-check.ps1`](scripts/monthly-check.ps1) | 唯讀的每月安全檢查（`-Scheduled` 寫記錄、有問題才跳窗；`-NoPopup` 只寫記錄） |
| [`scripts/monthly-summary.ps1`](scripts/monthly-summary.ps1) | 每月 2 號彙總各台檢查結果 |
| [`scripts/register-monthly-tasks.ps1`](scripts/register-monthly-tasks.ps1) | 建立上面兩個工作排程 |

## 實作中遇到的問題與解法

| 問題 | 原因 | 解法 |
| --- | --- | --- |
| iPhone 連 Android 手機一直卡在「已連線，等待畫面傳輸」，電腦連同一支手機正常 | 疑似 iOS 版 RustDesk 與 Android 被控端的相容性問題（換編碼、關硬體編碼、保持螢幕亮著都無效，未確認根因） | 用常開桌電當跳板：iPhone → 桌電 → 手機 |
| 從遠端畫面點不到桌電上的 RustDesk 主視窗（畫面是白的） | 推測是 RustDesk 不讓自己的視窗被擷取／操作（其他視窗都正常） | 寫 bat 用 `RustDesk.exe --connect <IP>` 直接開連線視窗，繞過主視窗 |
| 雙擊 bat 完全沒反應 | 檔案是 LF 換行 + UTF-8 中文，cmd 解析失敗 | bat 一律 CRLF + 純 ASCII，寫完實測 |
| 用 PowerShell 改防火牆規則的 IP 時報錯「委託給使用者…」 | Windows 跳「允許存取」視窗時自動建立的規則，邊緣周遊設定是「交給使用者決定」 | 改 IP 時同時加 `-EdgeTraversalPolicy Block` |
| 刪掉「重複」的防火牆規則後，只剩輸出規則 | 兩條同名規則一條是 Inbound、一條是 Outbound，比對時沒看方向 | 比對規則一定列出 Direction／Profile；每月檢查腳本會檢查有沒有 Inbound 規則 |
| 以為 Windows 防火牆的 IP 限制是第二道門，其實沒擋到 | Tailscale 自建的 `Tailscale-In` 規則放行 Private 網路的所有連入 | 認清真正的關卡是 Tailscale ACL 與 RustDesk 白名單／密碼／2FA，文件改正確 |
| Android 手機上 RustDesk 平常沒用，幾個月後權限可能被收回 | Android「管理未使用的應用程式」會自動移除權限 | 對 RustDesk、Tailscale 關掉這個選項 |
| 螢幕一鎖，手機端的螢幕錄製就停止 | 新版 Android 的安全限制 | 寫進家人 SOP：連線期間手機保持亮著 |
| 電視播 Netflix 時 scrcpy 畫面全黑 | DRM 保護 | 請家人先退回電視首頁 |
| 檢查腳本在 PowerShell 5.1 讀 `tailscale status --json` 解析失敗 | `tailscale.exe` 輸出 UTF-8，PowerShell 5.1 用舊碼頁解讀，中文顯示名稱被讀壞、吃掉引號 | 呼叫前設定 `[Console]::OutputEncoding = UTF8`；.ps1 本身維持純 ASCII，中文用 `\u` 跳脫 |
| 筆電的排程第一次執行失敗（結果碼 1），手動執行卻正常 | 剛改完腳本，筆電的 OneDrive 還沒同步到新版，排程跑到不認得新參數的舊版 | 改完腳本等各台同步完成再測（實際環境的設定腳本會先比對檔案指紋，版本不對就停止） |
| 經 RustDesk 把長指令貼進遠端電腦，PowerShell 一直停在 `>>` | 遠端剪貼簿把長行截斷，引號不成對 | 改成把設定寫成腳本檔放共用資料夾，遠端只貼一行短指令 |
| 家人電腦的檢查要在沒人登入時也能跑，又不能跳視窗嚇到家人 | 以使用者身分執行需要登入，而且視窗會出現在家人螢幕上 | 家人電腦用 SYSTEM 身分、只寫記錄；由桌電隔天彙總、出問題在我的螢幕提醒 |
| 想遠端看歡唱機畫面，但它接在 Sony 電視上 | 該型號 Sony 電視不是 Android TV，沒有 ADB | 評估 KVM 盒、擷取卡等方案，暫不實作 |

## 刻意不做的事

- **Tailnet Lock**：能防「帳號被盜後被加入陌生設備」。評估家用風險與保存停用密鑰的成本後，決定延後；文件有記錄啟用條件與準備事項。
- **Windows RDP**：家用版 Windows 不能當 RDP 被控端，也不使用 RDP Wrapper 這類修改系統檔的工具。

## 使用的工具

| 工具 | 用途 | 授權 |
| --- | --- | --- |
| [Tailscale](https://tailscale.com/) | 加密內網（WireGuard）、ACL、設備標籤與核准 | BSD-3-Clause（用戶端）／Personal 方案限非商用 |
| [RustDesk](https://rustdesk.com/) | 遠端桌面（電腦、Android 手機），只用直接 IP | AGPL-3.0 |
| [scrcpy](https://github.com/Genymobile/scrcpy) + adb | 控制 Android TV | Apache-2.0 |
| PowerShell / Batch | 每月檢查與彙總腳本、一鍵連線捷徑 | 本 repo（PolyForm Noncommercial） |
| Windows 工作排程器 | 每月自動執行檢查（使用者／SYSTEM 兩種身分） | Windows 內建 |
| OneDrive | 各台檢查記錄的匯集管道 | 微軟服務條款 |

## 與 AI 協作

整個專案用 Claude Code 協作完成：需求、架構取捨與上線決策由我決定；AI 負責查資料、在本機執行檢查與設定、產出文件與腳本，每個步驟都實測驗收後才記錄為完成。

## 授權

- **本 repo 作者撰寫的內容：非商業使用免費，商業使用須先取得授權。** 文件採 [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)，腳本採 [PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/)，細節見 [LICENSE.md](LICENSE.md)。
- **第三方軟體不在本 repo 內**，各自適用原授權：Tailscale 用戶端 BSD-3-Clause（免費 Personal 方案不適用商業使用，商用需付費方案）、RustDesk AGPL-3.0（Server Pro 為付費商業授權）、scrcpy Apache-2.0。整理表見 [LICENSE.md](LICENSE.md#第三方軟體)。

## 免責聲明

這是個人家用環境的紀錄，不是商業產品。照著做之前，請依自己的設備與風險評估調整；所有範例 IP 與名稱都需要換成你自己的。
