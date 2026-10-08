# AudioZoom 🎬🔊

> **Sese duyarlı video zoom efekti — FFmpeg + PowerShell**
> Geliştirici: [@metatronslove](https://github.com/metatronslove)

[![001 In Silentio Monadis — Orjinal Kaynak](https://img.youtube.com/vi/KZq1ZIXOuN0/maxresdefault.jpg)](https://youtu.be/KZq1ZIXOuN0)

> 🎥 Yukarıdaki **"001 In Silentio Monadis"** videosu, bu script kullanılarak sesin enerji akışına göre otomatik zoom uygulanarak dönüştürülmüştür.
> İzlemek için:

[![001 In Silentio Monadis — AudioZoom ile Dönüştürüldü](https://img.youtube.com/vi/9kSGjEhu6H4/maxresdefault.jpg)](https://youtu.be/9kSGjEhu6H4)

---

## 📖 Bu Proje Nedir?

**AudioZoom**, bir video dosyasının ses kanalını analiz ederek **ses enerjisine göre yatay/dikey zoom** efekti uygulayan bir PowerShell script'idir. Müzik videolarını, canlı performansları veya ses içeren herhangi bir videoyu, sesin akışıyla uyumlu bir şekilde "nefes alıp veren" bir görselleştirmeye dönüştürür.

Klasik yaklaşım olan dev bir FFmpeg `zoompan` ifadesi, uzun videolarda bellek limitini (`-12 Cannot allocate memory`) aştığı için bu proje **parçalı render mimarisi** kullanır: video küçük parçalara bölünür, her parça ayrı ayrı işlenir, sonra birleştirilir.

### ✨ Öne Çıkan Özellikler

| Özellik | Açıklama |
|---|---|
| 🎚️ **Profesyonel ses işleme** | dB cinsinden loudness, asimetrik attack/release envelope follower, yüzdelik normalizasyon (%5–%95), gamma eğrisi |
| 🧩 **Parçalı render mimarisi** | Bellek limitini aşmaz; saatlerce uzunluktaki videolarda dahi güvenle çalışır |
| 📐 **Piksel bazlı zoom kontrolü** | "Her kenardan 60 piksel" gibi sezgisel parametrelerle hassas kontrol |
| 🔊 **Kayıpsız ses** | Orijinal ses akışı yeniden encode edilmeden mux edilir |
| 🌍 **Kültürden bağımsız** | tr-TR, de-DE gibi ondalık virgül kullanan sistemlerde de çalışır |
| 🎛️ **Zengin kalibrasyon** | `EnergyMode`, `AttackMs`, `ReleaseMs`, `Gamma`, `UpdateHz` ile müzik türüne göre ince ayar |
| 🛡️ **Otomatik güvenlik** | Segment sayısı çok arttığında parça süresini otomatik küçültür |

---

## 🖥️ Sistem Gereksinimleri

| Bileşen | Minimum | Önerilen |
|---|---|---|
| **İşletim Sistemi** | Windows 10 | Windows 11 |
| **PowerShell** | 5.1 (yerleşik) | PowerShell 7+ |
| **FFmpeg** | 5.0 | 9.x (Gyan build) |
| **Disk alanı** | ~2× çıktı boyutu | Geçici parçalar için |
| **RAM** | 4 GB | 8 GB+ |

---

## 🛠️ Windows 11 — FFmpeg Kurulumu

FFmpeg kurulumu için **4 yöntemden birini** seçin. `ffmpeg` **ve** `ffprobe` aynı pakette gelir.

### Yöntem 1 — `winget` (En kolay, Windows 11'de yerleşik)

Yönetici **gerekmez**. PowerShell açın ve şunu çalıştırın:

```powershell
winget install Gyan.FFmpeg
```

Kurulumdan sonra **yeni bir PowerShell penceresi açın** (PATH güncellenmesi için) ve doğrulayın:

```powershell
ffmpeg -version
ffprobe -version
```

Her ikisi de sürüm numarası döndürmelidir.

### Yöntem 2 — Chocolatey (Otomasyon sevenler için)

Chocolatey kurulu değilse önce yönetici PowerShell'de:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = `
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

Sonra:

```powershell
choco install ffmpeg -y
```

Doğrulama:

```powershell
ffmpeg -version
```

### Yöntem 3 — Scoop (Geliştirici dostu)

Scoop kurulu değilse:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

Sonra:

```powershell
scoop install ffmpeg
```

Doğrulama:

```powershell
ffmpeg -version
```

### Yöntem 4 — Manuel Kurulum (Taşınabilir)

1. <https://www.gyan.dev/ffmpeg/builds/> adresine gidin.
2. **`ffmpeg-release-essentials.zip`** dosyasını indirin.
3. ZIP'i `C:\ffmpeg` gibi bir klasöre çıkarın (içinde `bin\ffmpeg.exe` olmalı).
4. **Başlat → "Ortam Değişkenleri"** yazıp **"Sistem ortam değişkenlerini düzenle"**yi açın.
5. **Ortam Değişkenleri → Sistem değişkenleri → `Path`** seçin → **Düzenle** → **Yeni** → `C:\ffmpeg\bin` yazın.
6. Tamam'a basın, **yeni bir PowerShell penceresi** açın, `ffmpeg -version` ile doğrulayın.

### ✅ Kurulum Doğrulaması

Hangi yöntemi kullanırsanız kullanın:

```powershell
ffmpeg -version
ffprobe -version
```

Her ikisi de sürüm bilgisi döndürüyorsa hazırsınız.

---

## 🚀 Hızlı Başlangıç

1. **`AudioZoom.ps1`** dosyasını bir klasöre kaydedin (örneğin `E:\Projeler\AudioZoom\`).
2. Videoyu aynı klasöre koyun (veya tam yol verin).
3. PowerShell'i o klasörde açın ve çalıştırın:

```powershell
.\AudioZoom.ps1 "video.mp4" -MaxZoomPixels 60
```

4. İlk çalıştırmada execution policy hatası alırsanız, o oturum için:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

5. Çıktı: `video_zoomed.mp4` (girdi ile aynı klasörde).

---

## ⚙️ Parametreler

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-InputFile` | string | **zorunlu** | Girdi video dosyası (konumsal 0) |
| `-OutputFile` | string | `<input>_zoomed.mp4` | Çıktı dosyası (konumsal 1) |
| `-MaxZoomPixels` | int | `50` | Her kenardan en fazla kaç piksel kırpılacak. `0` = piksel modu kapalı |
| `-PixelReference` | enum | `Shorter` | Referans kenar: `Shorter`, `Longer`, `Width`, `Height` |
| `-MinZoom` | double | `1.00` | Zoom alt sınırı (`1.0` = zoom yok) |
| `-MaxZoom` | double | `1.12` | Zoom üst sınırı (yalnız `-MaxZoomPixels 0` iken) |
| `-EnergyMode` | enum | `Loudness` | Enerji ölçüm modu: `Loudness`, `RMS`, `Peak` |
| `-AttackMs` | int | `15` | Zarf yükselme süresi (ms). Küçük = keskin tepki |
| `-ReleaseMs` | int | `250` | Zarf düşme süresi (ms). Büyük = uzun süren zoom |
| `-PercentileLow` | double | `5.0` | Normalizasyon alt yüzdelik |
| `-PercentileHigh` | double | `95.0` | Normalizasyon üst yüzdelik |
| `-Gamma` | double | `0.8` | Eğri katsayısı. `<1` küçük sesleri şişirir, `>1` büyükleri vurgular |
| `-UpdateHz` | int | `15` | Zoom güncelleme frekansı (Hz) |
| `-ChunkSeconds` | int | `30` | Render parçası uzunluğu (sn) |
| `-DeltaThreshold` | double | `0.0005` | Kümülatif toplamda atlanacak minimum değişim |
| `-Crf` | int | `20` | x264 kalite (düşük = iyi kalite) |
| `-KeepTemp` | switch | — | Geçici dosyaları silme (hata ayıklama) |

### ⚠️ Kritik Kural: `ChunkSeconds ≤ 200 / UpdateHz`

FFmpeg'in `zoompan` expression parser'ı parça başına ~400 terimden sonra bellek ayıramıyor. **Güvenli sınır: parça başına ≤ 200 segment.** Script bunu otomatik denetler ve gerektiğinde parça süresini küçültür.

| `UpdateHz` | Maks. `ChunkSeconds` | Parça başına segment |
|---|---|---|
| 3 | 60 | 180 |
| 5 | 40 | 200 |
| 8 | 25 | 200 |
| 12 | 16 | 192 |
| 15 | 13 | 195 |
| 20 | 10 | 200 |
| 30 | 6 | 180 |

---

## 📚 Kullanım Örnekleri

### 1️⃣ Basit kullanım — Varsayılan ayarlar

```powershell
.\AudioZoom.ps1 "song.mp4"
```

50 px'lik zoom, kısa kenar referansı, 15 Hz, Loudness modu.

### 2️⃣ Belirli piksel değeri

```powershell
.\AudioZoom.ps1 "song.mp4" -MaxZoomPixels 60
```

Her kenardan 60 px kırpma. 1080p'de ≈ %6,3 yakınlaşma.

### 3️⃣ Özel çıktı adı

```powershell
.\AudioZoom.ps1 "girdi.mp4" "cikti_zoom.mp4" -MaxZoomPixels 80
```

### 4️⃣ Genişlik referansı (dikey video için)

```powershell
.\AudioZoom.ps1 "vertical.mp4" -MaxZoomPixels 80 -PixelReference Width
```

### 5️⃣ Beat-sync (elektronik/dance)

```powershell
.\AudioZoom.ps1 "dance.mp4" `
    -MaxZoomPixels 80 `
    -EnergyMode Peak `
    -UpdateHz 30 `
    -ChunkSeconds 6 `
    -AttackMs 5 `
    -ReleaseMs 120 `
    -Gamma 0.9
```

### 6️⃣ Ambient/klasik (yumuşak nefes alma)

```powershell
.\AudioZoom.ps1 "silentio.mp4" `
    -MaxZoomPixels 70 `
    -EnergyMode Loudness `
    -UpdateHz 12 `
    -ChunkSeconds 5 `
    -AttackMs 25 `
    -ReleaseMs 400 `
    -Gamma 0.7
```

**Bu komut, README'nin başındaki YouTube videosunu üreten komuttur.**

### 7️⃣ Hızlı test (ilk 30 sn'yi dene)

```powershell
.\AudioZoom.ps1 "song.mp4" "test30.mp4" -MaxZoomPixels 60 -UpdateHz 12 -ChunkSeconds 5
```

Kalibrasyonu tam videoda yapmadan önce küçük bir bölümde deneyin.

---

## 🧠 Kod Nasıl Çalışır?

### Genel Akış

```
┌──────────────────────────────────────────────────────────────┐
│  1. Metadata Okuma (ffprobe)                                 │
│     └─→ fps, süre, çözünürlük                                │
├──────────────────────────────────────────────────────────────┤
│  2. PCM Çıkarma (ffmpeg)                                     │
│     └─→ 8 kHz mono s16le → ham ses verisi                    │
├──────────────────────────────────────────────────────────────┤
│  3. Kare Başına Enerji                                       │
│     └─→ Loudness / RMS / Peak                                │
├──────────────────────────────────────────────────────────────┤
│  4. Asimetrik Envelope Follower                              │
│     └─→ Attack (hızlı) + Release (yavaş)                     │
├──────────────────────────────────────────────────────────────┤
│  5. Yüzdelik Normalizasyon + Gamma                           │
│     └─→ [0, 1] aralığına sıkıştırma                          │
├──────────────────────────────────────────────────────────────┤
│  6. Segmentasyon (peak-hold)                                 │
│     └─→ Zoom değerleri dizisi                                │
├──────────────────────────────────────────────────────────────┤
│  7. Parçalı Render                                           │
│     └─→ Her parça için küçük zoompan ifadesi                 │
├──────────────────────────────────────────────────────────────┤
│  8. Concat (parçaları birleştir)                             │
├──────────────────────────────────────────────────────────────┤
│  9. Ses Mux (orijinal sesi kayıpsız ekle)                    │
└──────────────────────────────────────────────────────────────┘
```

### Adım Adım Detay

#### 🎯 1. Metadata Okuma
`ffprobe` ile videonun fps'i, süresi ve çözünürlüğü JSON olarak alınır. Bu bilgiler:
- kare başına segment sayısını,
- piksel → çarpan dönüşümünü,
- filtre çözünürlüğünü belirlemek için kullanılır.

#### 🎯 2. Ses Verisi Çıkarma
Ses, **8 kHz mono 16-bit PCM** olarak çıkarılır. Neden bu kadar düşük örnekleme? Çünkü:
- Zoom eğrisi için yüksek frekans bilgisine ihtiyaç yok.
- Dosya boyutu küçük kalır (5 dakikalık ses ≈ 5 MB).
- PowerShell döngüsü hızlı çalışır.

#### 🎯 3. Kare Başına Enerji Hesabı
Her video karesine karşılık gelen ses örnekleri üzerinden enerji hesaplanır. Üç mod:

| Mod | Formül | Kullanım |
|---|---|---|
| **Loudness** | `20·log10(RMS)` | Algıya en yakın, varsayılan |
| **RMS** | `sqrt(Σx²/n)` | Lineer enerji |
| **Peak** | `max(|x|)` | Anlık tepe değeri |

Loudness modunda sessiz bölgeler `-120 dB` olarak işaretlenir (log(0) hatasını önlemek için).

#### 🎯 4. Asimetrik Envelope Follower
Analog kompresör mantığı:

```
y[n] = coef·y[n-1] + (1-coef)·x[n]

Attack (yükselme):  coef = exp(-1 / (AttackMs  / 1000 · fps))
Release (düşme):   coef = exp(-1 / (ReleaseMs / 1000 · fps))
```

- **Attack** küçükse (`5–15 ms`): ses ani yükseldiğinde zoom da hızlı yükselir.
- **Release** büyükse (`200–500 ms`): ses düştükten sonra zoom bir süre yüksek kalır → vuruş "yayılır".

Bu asimetri, klasik simetrik smoothing'in aksine gerçek müzik dinamiğini yakalar.

#### 🎯 5. Yüzdelik Normalizasyon + Gamma
Min-max normalizasyonu **yanlıştır**: tek bir zil çarpması `mx`'i tepeye sabitler, geri kalan her şey küçük görünür. Bunun yerine:

- `%5`'lik dilim = alt referans (sessizlik)
- `%95`'lik dilim = üst referans (güçlü vuruş)
- Aradaki değerler `[0, 1]`'e lineer eşlenir.
- Sonra **gamma eğrisi** uygulanır: `norm^gamma`. `Gamma < 1` küçük değerleri şişirir; `Gamma > 1` büyükleri vurgular.

#### 🎯 6. Segmentasyon (Peak-Hold)
Zoom eğrisi, `UpdateHz` frekansında segmentlere indirgenir. **Her segmentin değeri o segmentteki maksimumdur** — ortalama değil. Bu, segment içindeki kısa vuruşların kaybolmamasını sağlar.

#### 🎯 7. Parçalı Render (Bellek Dostu Mimari)
Video, `ChunkSeconds` uzunluğunda parçalara bölünür. Her parça için:
- Global zoom dizisinden **yalnız o parçaya ait** segmentler çıkarılır.
- Yerel zamanlara çevrilir (`tLocal = tGlobal - chunkStart`).
- Düz kümülatif toplam olarak ifade edilir:

```
z(t) = z0 + Σ (z_{i+1} - z_i) · gte(t, t_{i+1})
```

`gte(x, y)`: `x ≥ y` ise 1, değilse 0. **İç içe `if()` yok** — parser recursion limiti aşılmaz.

Her parça `setpts=PTS-STARTPTS` ile başlatılır (yerel zaman sıfırlanır).

#### 🎯 8. Concat
Parçalar `concat` demuxer ile **yeniden encode edilmeden** (`-c copy`) birleştirilir. Saniyeler içinde tamamlanır.

> ⚠️ **Önemli:** concat.txt dosyası **BOM'suz ASCII** yazılır. UTF-8 encoding kullanılırsa PowerShell 5.1 BOM ekler ve FFmpeg `unknown keyword 'file'` hatası verir.

#### 🎯 9. Ses Mux
Orijinal video dosyasının ses akışı (`-c:a copy`), birleştirilmiş video parçalarının üzerine **kayıpsız** olarak eklenir. Bu sayede:
- Parça sınırlarında tık/boşluk olmaz.
- Ses yeniden encode edilmediği için kalite kaybı sıfırdır.

---

## 🎛️ Kalibrasyon Rehberi

Aşağıdaki preset'lerden birini başlangıç noktası olarak kullanın, kulağınıza göre ayarlayın.

| Müzik Türü | `EnergyMode` | `UpdateHz` | `AttackMs` | `ReleaseMs` | `Gamma` | `MaxZoomPixels` |
|---|---|---|---|---|---|---|
| **Klasik / Ambient** | Loudness | 8 | 40 | 500 | 0.6 | 40 |
| **Pop / Rock** | Loudness | 15 | 15 | 250 | 0.8 | 60 |
| **Elektronik / Dance** | Peak | 30 | 5 | 120 | 0.9 | 80 |
| **Hip-Hop (bas vuruşu)** | Peak | 20 | 8 | 180 | 1.1 | 70 |
| **Caz / Akustik** | Loudness | 12 | 20 | 300 | 0.75 | 50 |

### İnce Ayar İpuçları

- **Zoom çok hızlı hareket ediyor:** `-AttackMs` ve `-ReleaseMs` değerlerini büyütün.
- **Küçük sesler görünmüyor:** `-Gamma`'yı küçültün (örn. `0.5`).
- **Her şey aynı görünüyor:** `-PercentileHigh`'ı düşürün (örn. `90`).
- **Zoom takılıyor/atlıyor:** `-UpdateHz`'i artırın (parça süresini küçültmeyi unutmayın).
- **Ses geç tepki veriyor:** `-AttackMs`'i küçültün.

---

## 🐛 Sorun Giderme

### ❌ `-12 Cannot allocate memory` (FFmpeg)
**Sebep:** Parça başına segment sayısı çok yüksek.
**Çözüm:** `-ChunkSeconds` değerini `200 / UpdateHz` formülüne göre küçültün. Örneğin `-UpdateHz 15` için `-ChunkSeconds 13` yeterli.

### ❌ `unknown keyword 'file'` (concat)
**Sebep:** concat.txt dosyası BOM ile başlıyor.
**Çözüm:** Script güncel sürümde `[Text.Encoding]::ASCII` kullanır. Eski bir sürüm kullanıyorsanız güncelleyin.

### ❌ `The term '.\AudioZoom.ps1' is not recognized`
**Sebep:** Dosya adı uyuşmazlığı veya yanlış klasör.
**Çözüm:** `Get-ChildItem *.ps1` ile doğru ismi bulun.

### ❌ `cannot be loaded because running scripts is disabled`
**Sebep:** PowerShell execution policy.
**Çözüm:**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### ❌ `ffmpeg : The term 'ffmpeg' is not recognized`
**Sebep:** FFmpeg PATH'e eklenmemiş.
**Çözüm:** Kurulumdan sonra **yeni bir PowerShell penceresi** açın. Hâlâ çalışmıyorsa FFmpeg'i manuel olarak PATH'e ekleyin (yukarıdaki Yöntem 4).

### ❌ Filtre ifadesinde ondalık virgül
**Sebep:** tr-TR yerel ayarı.
**Çözüm:** Script `InvariantCulture` kullanır; güncel sürümde bu sorun yoktur.

---

## 📁 Proje Yapısı

```
AudioZoom/
├── README.md           ← bu dosya
└── AudioZoom.ps1       ← ana script
 
```

---

## 🤝 Katkıda Bulunma

1. Fork'layın.
2. Yeni bir branch açın (`git checkout -b ozellik/yeni-ozellik`).
3. Değişikliklerinizi commit'leyin (`git commit -m 'Yeni özellik: X'`).
4. Branch'i push'layın (`git push origin ozellik/yeni-ozellik`).
5. Pull Request açın.

---

## 📜 Lisans

MIT Lisansı. Detaylar için `LICENSE` dosyasına bakın.

---

## 👤 Geliştirici

**metatronslove**
- GitHub: [@metatronslove](https://github.com/metatronslove)
- YouTube: [Kanal](https://youtu.be/KZq1ZIXOuN0)

---

## 🙏 Teşekkürler

- **FFmpeg ekibine** — bu projenin temelini oluşturan olağanüstü multimedia çatısı için.
- **Gyan Doshi** — Windows için stabil FFmpeg build'leri.
- **Tüm katkıda bulunanlara** — geri bildirim ve test için.

---

## 📊 Sürüm Geçmişi

### v1.0.0 — İlk Stabil Sürüm
- ✅ Parçalı render mimarisi (bellek limiti çözümü)
- ✅ Asimetrik envelope follower
- ✅ Yüzdelik normalizasyon + gamma
- ✅ Peak-hold segmentasyon
- ✅ Piksel bazlı zoom kontrolü
- ✅ FFmpeg 9+ uyumluluğu (`-/filter_complex`)
- ✅ Kültürden bağımsız sayı formatlama
- ✅ Otomatik parça süresi güvenlik denetimi
