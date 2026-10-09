# Pull Request

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

<a id="en"></a>

## English

### What changed and why

<!-- One logical change per PR. State what, why, and how. -->

### Verification

- [ ] `Invoke-Pester -Path ./Tests` passes (all tests green)
- [ ] `.ps1` files pass the parser syntax check
- [ ] `.bat` files pass a dry review of quoted paths and `%ERRORLEVEL%` handling
- [ ] No trailing whitespace in added lines
- [ ] `.gitignore` scope checked for new files (logs stay out)
- [ ] Commit messages: English, imperative, `type:` prefix with bullet body

### Security

- [ ] No secrets, tokens, or personal data in diffs or messages
- [ ] No new network calls or persisted elevation (except `WinGet-Upgrade.bat` via `winget`)

<a id="tr"></a>

## Türkçe

### Ne değişti ve neden

<!-- PR başına tek mantıksal değişiklik. Neyi, neden ve nasıl yaptığınızı yazın. -->

### Doğrulama

- [ ] `Invoke-Pester -Path ./Tests` geçiyor (tüm testler yeşil)
- [ ] `.ps1` dosyaları ayrıştırıcı sözdizimi denetiminden geçiyor
- [ ] `.bat` dosyaları alıntılanan yollar ve `%ERRORLEVEL%` işlemenin kuru gözden geçirmesinden geçiyor
- [ ] Eklenen satırlarda sondan boşluk yok
- [ ] Yeni dosyalar için `.gitignore` kapsamı denetlendi (günlükler dışarıda)
- [ ] Commit iletileri: İngilizce, buyruk kipi, madde açıklamalı `type:` öneki

### Güvenlik

- [ ] Farklarda ya da iletilerde sır, jeton veya kişisel veri yok
- [ ] Yeni ağ çağrısı veya kalıcı yetki yükseltme yok (`winget` üzerinden `WinGet-Upgrade.bat` dışında)
