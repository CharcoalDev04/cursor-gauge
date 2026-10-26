# Cursor Gauge

[English](#english) · [ภาษาไทย](#ภาษาไทย)

![Cursor Gauge panel](docs/screenshot.png)

---

## English

A lightweight macOS menu bar app that shows your Cursor plan usage and how much you have left this billing cycle.

No browser tab, no manual cookie paste — Cursor Gauge reads your session from the local Cursor IDE database and fetches usage from Cursor's dashboard API.

Cursor Gauge is a fork of [CursorBar](https://github.com/c-johannesen/cursorbar) by [c-johannesen](https://github.com/c-johannesen).

### Features

- **Menu bar icon** — a system gauge symbol plus the figures you turn on in Settings. A yellow badge means an agent needs input. With every switch off, only the gauge remains
- **Configurable menu bar** — Settings chooses gauge, quota percent, agent badge, today percent, remaining money, and overspend. The dropdown still shows the full panel
- **Languages** — System, Thai, or English. Dates and currency follow the Mac
- **Daily utilization** — today's spend, from local midnight, measured against a daily budget (total quota / working days in the billing cycle). Near the daily budget turns yellow; over 100% turns red
- **Pool breakdown** — shows the included balance, the Composer / Cursor Models pool (`$200` Pro `1x` / `$600` Pro+ `3x` / `$4,000` Ultra `20x` floor, scaled dynamically from actual usage and percent), and the API / Other Models pool (`plan.limit`, or `$20` Pro / `$70` Pro+ / `$400` Ultra)
- **Models & tokens** — top models by spend this cycle, plus cycle and all-time token totals from your public Cursor profile
- **Overspend tracking** — shows charges beyond the included pool and on-demand spend with budget/remaining
- **Billing cycle info** — current period dates and days until reset
- **Auto-refresh** — on launch and every 5 minutes, with a manual Refresh button anytime
- **Built-in updates** — checks GitHub Releases on startup, with a manual check button and one-click update from Settings

### Requirements

- macOS 26 or later
- [Cursor IDE](https://cursor.com) installed and signed in on this Mac
- Swift 6 — only needed if [building from source](#build-from-source)

### Install

#### Homebrew

```bash
brew tap charcoaldev04/cursor-gauge
brew trust charcoaldev04/cursor-gauge
brew install --cask cursor-gauge
```

This installs `Cursor Gauge.app`. The tap is [homebrew-cursor-gauge](https://github.com/CharcoalDev04/homebrew-cursor-gauge). Homebrew 7 will not install a third-party cask until the tap is trusted.

#### Download

Download the latest `CursorGauge-*.zip` from [Releases](https://github.com/CharcoalDev04/cursor-gauge/releases), unzip it, and move `Cursor Gauge.app` to `/Applications`. Then open it:

```bash
open -a "Cursor Gauge"
```

#### Build from source

```bash
git clone https://github.com/CharcoalDev04/cursor-gauge.git
cd cursor-gauge
bash scripts/install.sh
```

This builds Cursor Gauge locally, installs it to `/Applications/Cursor Gauge.app`, and opens it.

#### Launch later

```bash
open -a "Cursor Gauge"
```

Or, if you built from source:

```bash
bash scripts/launch.sh
```

### Usage

| Menu bar | Click to open dropdown |
|----------|------------------------|
| Gauge and the figures you enabled | Click to open the panel |

**Menu bar**

- Yellow badge — that many agents need your input
- Yellow today percent — today's spend is at 90–100% of the daily budget
- Red quota or today percent — quota is at or over 100% (or there is overspend), or today's spend is over 100%
- Dim gauge — nothing is running and quota is 0%

Agent status is read from local Cursor IDE data (transcripts and `state.vscdb`). Cloud agent status and plan/input flags can lag the UI by a minute or two because the IDE debounces writes to disk. Click an agent under **Needs input** to focus it in the Cursor app.

**Color in the panel**

- Yellow value — today's spend is at 90–100% of the daily budget
- Red value — a pool is at 100% or today's spend is over 100%

**Auto-refresh:** immediately on launch, then every **5 minutes** while the app is running.

**Errors:** if something goes wrong, the menu bar shows `!` — open the dropdown for details.

### Troubleshooting

Check that Cursor Gauge can read your account:

```bash
"/Applications/Cursor Gauge.app/Contents/MacOS/CursorGauge" --status
```

Expected output: `OK 42%` (your percentage will differ).

Common issues:

| Problem | Fix |
|---------|-----|
| `!` in menu bar | Make sure Cursor is installed and you're signed in, then click **Refresh** |
| App won't open from Finder | Run `bash scripts/launch.sh` or `xattr -cr "/Applications/Cursor Gauge.app"` — clears Gatekeeper quarantine flags |
| `Swift is not installed` | Run `xcode-select --install` |
| `No auth token found` | Sign out and back into Cursor, then relaunch Cursor Gauge |
| `Could not parse auth token` | Update Cursor Gauge. Current Cursor seals the login token; signing in again does not turn it back into a JWT. If macOS asks, allow Keychain access to **Cursor Safe Storage** |

### How it works

1. Reads `cursorAuth/accessToken` from Cursor's local SQLite database  
   `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
2. If Cursor sealed the token (`cursor-safe-storage:v1:`), decrypts it with the **Cursor Safe Storage** keychain item, then derives a session cookie from the JWT
3. Calls `GET https://cursor.com/api/usage-summary`, `POST https://cursor.com/api/dashboard/get-filtered-usage-events`, and your public Cursor profile for token totals

The token is read fresh on every refresh and is **never stored** by Cursor Gauge.

### Development

```bash
git clone https://github.com/CharcoalDev04/cursor-gauge.git
cd cursor-gauge

# Build only
bash scripts/package.sh

# Build, install to /Applications, and launch
bash scripts/package.sh --install --open

# Run self-checks
.build/release/CursorGauge --self-check

# Verify API access
.build/release/CursorGauge --status
```

Project layout:

```
Sources/CursorGauge/
  App.swift                   # MenuBarExtra entry point & CLI flags
  PanelView.swift             # Dropdown panel & Settings view
  MenuBarStatus.swift         # Menu bar gauge, figures, and badge
  MenuBarChrome.swift         # Menu bar luminance sampling
  MenuBarChromeMonitor.swift  # Dark/light menu bar observer
  L10n.swift                  # English & Thai strings
  AgentMonitor.swift          # Live agent count & needs-input detection
  TokenProvider.swift         # Read & decrypt auth from Cursor IDE DB
  CursorAPI.swift             # Fetch usage summary, events, and profile tokens
  UsageSummary+Resolved.swift # Pool limits & credit floors
  UsageMath.swift             # Daily pace, model ranking, and self-checks
  UsageStore.swift            # Refresh timer & display state
  UpdateChecker.swift         # GitHub release updates
scripts/
  install.sh                  # One-step build & install
  launch.sh                   # Start the app
  package.sh                  # Build .app bundle
  release.sh                  # Package release zip & tag
```

### Limitations

- Uses Cursor's **undocumented** dashboard API — may break without notice
- Agent status is inferred from local IDE files — may lag the UI or miss edge cases
- Individual Cursor accounts only (reads your local IDE session)
- Not signed with an Apple Developer ID — first launch may require right-click → Open, `xattr -cr`, or `scripts/launch.sh`

### Contributing

Pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

The `main` branch is protected: only the repository owner can push to or merge into `main`. Everyone else should fork the repo and open a PR.

### License

MIT — see [LICENSE](LICENSE).

Original work copyright (c) 2026 [c-johannesen](https://github.com/c-johannesen). This fork keeps that copyright notice.

---

## ภาษาไทย

แอปขนาดเล็กบนเมนูบาร์ macOS สำหรับดูโควต้าแพ็กเกจ Cursor และยอดคงเหลือในรอบบิลปัจจุบัน

ไม่ต้องเปิดแท็บเบราว์เซอร์หรือคัดลอกคุกกี้เอง — Cursor Gauge อ่านเซสชันจากฐานข้อมูลของ Cursor IDE บนเครื่อง แล้วดึงข้อมูลการใช้งานจาก Dashboard API ของ Cursor โดยตรง

Cursor Gauge พัฒนาต่อยอด (fork) จาก [CursorBar](https://github.com/c-johannesen/cursorbar) โดย [c-johannesen](https://github.com/c-johannesen)

### ฟีเจอร์

- **ไอคอนบนเมนูบาร์** — แสดงสัญลักษณ์เกจพร้อมตัวเลขที่เปิดไว้ในหน้าตั้งค่า ป้ายสีเหลืองหมายถึงมีเอเจนต์รอให้คุณตอบ ถ้าปิดทุกสวิตช์จะเหลือเฉพาะไอคอนเกจ
- **ปรับแต่งเมนูบาร์ได้** — เลือกเปิด/ปิด สัญลักษณ์เกจ, เปอร์เซ็นต์โควต้า, ป้ายเอเจนต์, เปอร์เซ็นต์วันนี้, เงินที่เหลือ และยอดเกินได้อิสระ ส่วนแผงด้านในยังแสดงข้อมูลครบทุกส่วน
- **รองรับหลายภาษา** — ตามระบบ, ไทย หรือ English โดยวันที่และสกุลเงินจะอิงตามการตั้งค่าของเครื่อง Mac
- **การใช้งานรายวัน (วันนี้)** — คำนวณยอดใช้ตั้งแต่เที่ยงคืนตามเวลาท้องถิ่นเทียบกับงบรายวัน (โควต้ารวม ÷ จำนวนวันทำการ จันทร์–ศุกร์ ในรอบบิล) เปลี่ยนเป็น **สีเหลือง** เมื่อใกล้เต็มงบ (`90–100%`) และเป็น **สีแดง** เมื่อเกิน `100%`
- **แยกโควต้าตามพูล** — แสดงยอดคงเหลือรวม, พูล **คอมโพเซอร์ / Cursor Models** (ขั้นต่ำ `$200` สำหรับ Pro `1x` / `$600` สำหรับ Pro+ `3x` / `$4,000` สำหรับ Ultra `20x` และปรับสเกลตามยอดใช้จริงกับ `%`), และพูล **API / Other Models** (`plan.limit` หรือ `$20` Pro / `$70` Pro+ / `$400` Ultra)
- **อันดับโมเดลและโทเคน** — แสดงโมเดลที่ใช้เงินสูงสุดในรอบบิลนี้ พร้อมจำนวนโทเคนรอบนี้และตลอดชีพจากโปรไฟล์สาธารณะของ Cursor
- **ติดตามยอดเกิน (Overspend)** — แสดงยอดใช้ที่เกินโควต้าที่รวมมา และยอดใช้จ่ายเพิ่ม (On-demand) พร้อมงบและยอดคงเหลือ
- **ข้อมูลรอบบิล** — แสดงวันที่เริ่ม–สิ้นสุดรอบบิล และจำนวนวันที่เหลือก่อนรีเซ็ต
- **รีเฟรชอัตโนมัติ** — อัปเดตทันทีเมื่อเปิดแอป และทุก ๆ 5 นาที หรือกดปุ่ม **รีเฟรช** ได้ตลอดเวลา
- **อัปเดตในตัว** — ตรวจหาเวอร์ชันใหม่จาก GitHub Releases เมื่อเปิดแอป พร้อมปุ่มตรวจอัปเดตและติดตั้งได้ในคลิกเดียวจากหน้าตั้งค่า

### ความต้องการของระบบ

- macOS 26 ขึ้นไป
- ติดตั้ง [Cursor IDE](https://cursor.com) และเข้าสู่ระบบไว้บนเครื่องนี้
- Swift 6 — ใช้เฉพาะกรณี[บิลด์จากซอร์สโค้ด](#บิลด์จากซอร์สโค้ด)

### วิธีติดตั้ง

#### Homebrew

```bash
brew tap charcoaldev04/cursor-gauge
brew trust charcoaldev04/cursor-gauge
brew install --cask cursor-gauge
```

คำสั่งนี้จะติดตั้ง `Cursor Gauge.app` จาก tap [homebrew-cursor-gauge](https://github.com/CharcoalDev04/homebrew-cursor-gauge) (บน Homebrew 7 ต้องรัน `brew trust` ก่อนติดตั้ง cask จาก tap ภายนอก)

#### ดาวน์โหลดไฟล์ติดตั้ง

ดาวน์โหลดไฟล์ `CursorGauge-*.zip` ล่าสุดจากหน้า [Releases](https://github.com/CharcoalDev04/cursor-gauge/releases) แตกไฟล์ แล้วลาก `Cursor Gauge.app` ไปไว้ที่ `/Applications` จากนั้นเปิดแอป:

```bash
open -a "Cursor Gauge"
```

#### บิลด์จากซอร์สโค้ด

```bash
git clone https://github.com/CharcoalDev04/cursor-gauge.git
cd cursor-gauge
bash scripts/install.sh
```

สคริปต์จะบิลด์ Cursor Gauge ติดตั้งไปยัง `/Applications/Cursor Gauge.app` และเปิดแอปให้อัตโนมัติ

#### การเปิดใช้งานในครั้งถัดไป

```bash
open -a "Cursor Gauge"
```

หรือถ้าบิลด์จากซอร์สโค้ด:

```bash
bash scripts/launch.sh
```

### การใช้งาน

| เมนูบาร์ | คลิกเพื่อเปิดแผงข้อมูล |
|----------|------------------------|
| สัญลักษณ์เกจและตัวเลขที่เปิดไว้ | คลิกเพื่อดูรายละเอียดและตั้งค่า |

**ความหมายบนเมนูบาร์**

- **ป้ายสีเหลือง** — จำนวนเอเจนต์ที่กำลังรอให้คุณตอบ
- **เปอร์เซ็นต์วันนี้สีเหลือง** — ยอดใช้วันนี้อยู่ที่ `90–100%` ของงบรายวัน
- **ตัวเลขสีแดง** — โควต้าถึงหรือเกิน `100%` (หรือมียอดเกิน) หรือยอดใช้วันนี้เกิน `100%`
- **ไอคอนเกจสีจาง** — ไม่มีเอเจนต์กำลังทำงานและโควต้าอยู่ที่ `0%`

สถานะเอเจนต์อ่านจากข้อมูลของ Cursor IDE บนเครื่อง (ไฟล์ transcript และ `state.vscdb`) สถานะของ Cloud Agent และการรออินพุตอาจดีเลย์จากหน้าจอหลักประมาณ 1–2 นาทีตามจังหวะที่ IDE เขียนข้อมูลลงดิสก์ สามารถคลิกชื่อเอเจนต์ใต้หัวข้อ **รอให้ตอบ** เพื่อสลับไปยังหน้าต่าง Cursor ได้ทันที

**สีของตัวเลขในแผงข้อมูล**

- **สีเหลือง** — ยอดใช้วันนี้อยู่ที่ `90–100%` ของงบรายวัน
- **สีแดง** — พูลนั้นใช้ถึง `100%` หรือยอดใช้วันนี้เกิน `100%`

**รีเฟรชอัตโนมัติ:** ทันทีที่เปิดแอป และทุก ๆ **5 นาที** ขณะเปิดแอปไว้

**ข้อผิดพลาด:** หากเกิดปัญหา เมนูบาร์จะแสดงเครื่องหมาย `!` สามารถเปิดแผงขึ้นมาดูสาเหตุได้

### การแก้ปัญหาเบื้องต้น

ตรวจสอบว่า Cursor Gauge อ่านข้อมูลบัญชีของคุณได้หรือไม่:

```bash
"/Applications/Cursor Gauge.app/Contents/MacOS/CursorGauge" --status
```

ผลลัพธ์ที่ควรได้: `OK 42%` (ตัวเลขขึ้นอยู่กับการใช้งานจริง)

ปัญหาที่พบบ่อย:

| ปัญหา | วิธีแก้ไข |
|-------|-----------|
| แสดง `!` บนเมนูบาร์ | ตรวจสอบว่าติดตั้งและเข้าสู่ระบบ Cursor แล้ว จากนั้นกดปุ่ม **รีเฟรช** |
| เปิดแอปจาก Finder ไม่ได้ | รัน `bash scripts/launch.sh` หรือ `xattr -cr "/Applications/Cursor Gauge.app"` เพื่อล้างสถานะกักกันของ Gatekeeper |
| `Swift is not installed` | รัน `xcode-select --install` |
| `No auth token found` / ไม่พบโทเคนเข้าสู่ระบบ | ออกจากระบบใน Cursor แล้วเข้าสู่ระบบใหม่ จากนั้นเปิด Cursor Gauge อีกครั้ง |
| `Could not parse auth token` / อ่านโทเคนเข้าสู่ระบบไม่ได้ | อัปเดต Cursor Gauge เป็นเวอร์ชันล่าสุด (Cursor รุ่นใหม่เข้ารหัสโทเคนไว้ การล็อกอินใหม่จะไม่เปลี่ยนกลับเป็น JWT เปล่า) หาก macOS ถามสิทธิ์ ให้กดอนุญาตเข้าถึง Keychain รายการ **Cursor Safe Storage** |

### หลักการทำงาน

1. อ่านค่า `cursorAuth/accessToken` จากฐานข้อมูล SQLite ของ Cursor บนเครื่อง  
   `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
2. หากโทเคนถูกเข้ารหัสไว้ (`cursor-safe-storage:v1:`) แอปจะถอดรหัสด้วยกุญแจ **Cursor Safe Storage** จาก Keychain ของ macOS แล้วสร้างคุกกี้เซสชันจาก JWT
3. เรียก `GET https://cursor.com/api/usage-summary`, `POST https://cursor.com/api/dashboard/get-filtered-usage-events` และหน้าโปรไฟล์สาธารณะของ Cursor เพื่อดึงยอดโทเคน

โทเคนจะถูกอ่านใหม่ทุกครั้งที่รีเฟรช และ **ไม่มีการบันทึกเก็บไว้** โดย Cursor Gauge

### สำหรับนักพัฒนา

```bash
git clone https://github.com/CharcoalDev04/cursor-gauge.git
cd cursor-gauge

# บิลด์อย่างเดียว
bash scripts/package.sh

# บิลด์ ติดตั้งลง /Applications และเปิดแอป
bash scripts/package.sh --install --open

# รันชุดตรวจสอบตัวเอง (self-check)
.build/release/CursorGauge --self-check

# ทดสอบการเรียก API
.build/release/CursorGauge --status
```

โครงสร้างโปรเจกต์:

```
Sources/CursorGauge/
  App.swift                   # จุดเข้า MenuBarExtra และแฟล็ก CLI
  PanelView.swift             # แผงดรอปดาวน์และหน้าตั้งค่า
  MenuBarStatus.swift         # เกจ ตัวเลข และป้ายบนเมนูบาร์
  MenuBarChrome.swift         # วัดความสว่างของเมนูบาร์
  MenuBarChromeMonitor.swift  # เฝ้าโหมดมืด/สว่างของเมนูบาร์
  L10n.swift                  # สตริงภาษาอังกฤษและไทย
  AgentMonitor.swift          # นับเอเจนต์ที่กำลังรันและที่รออินพุต
  TokenProvider.swift         # อ่านและถอดรหัสโทเคนจากฐานข้อมูล Cursor
  CursorAPI.swift             # ดึง usage summary, อีเวนต์ และยอดโทเคนจากโปรไฟล์
  UsageSummary+Resolved.swift # เพดานพูลและพื้นเครดิต
  UsageMath.swift             # จังหวะรายวัน อันดับโมเดล และ self-check
  UsageStore.swift            # ตัวจับเวลาอัปเดตและสถานะที่แสดง
  UpdateChecker.swift         # ตรวจอัปเดตจาก GitHub Releases
scripts/
  install.sh                  # บิลด์และติดตั้งในขั้นตอนเดียว
  launch.sh                   # เปิดแอป
  package.sh                  # สร้างบันเดิล .app
  release.sh                  # แพ็ก zip รีลีสและติดแท็ก
```

### ข้อจำกัด

- ใช้ Dashboard API ของ Cursor ที่ไม่ได้เปิดเผยเป็นทางการ ซึ่งอาจเปลี่ยนแปลงได้โดยไม่แจ้งล่วงหน้า
- สถานะเอเจนต์อนุมานจากไฟล์ของ IDE บนเครื่อง อาจมีความล่าช้าเล็กน้อย
- รองรับเฉพาะบัญชี Cursor ส่วนบุคคลที่ล็อกอินอยู่ใน IDE บนเครื่อง
- ไม่ได้ลงนามด้วย Apple Developer ID การเปิดครั้งแรกอาจต้องคลิกขวา → Open หรือรัน `xattr -cr` / `scripts/launch.sh`

### การมีส่วนร่วม

ยินดีรับพูลรีเควสต์ — ดู [CONTRIBUTING.md](CONTRIBUTING.md)

สาขา `main` ถูกป้องกันไว้: เฉพาะเจ้าของรีโปที่พุชหรือเมิร์จเข้า `main` ได้ คนอื่นให้ fork แล้วเปิด PR

### สัญญาอนุญาต

MIT — ดูรายละเอียดใน [LICENSE](LICENSE)

ลิขสิทธิ์ต้นฉบับ (c) 2026 [c-johannesen](https://github.com/c-johannesen) โดย fork นี้คงประกาศลิขสิทธิ์เดิมไว้ครบถ้วน
