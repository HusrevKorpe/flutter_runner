# Flutter Runner

Android Studio ya da VS Code açmadan Flutter uygulamasını simülatörde
çalıştırmak için küçük bir macOS aracı: **Run, Hot Reload, Restart, Stop,
DevTools**.

IDE'lerin kullandığı protokolün aynısını kullanır: `flutter run --machine`
başlatır ve komutları JSON olarak gönderir.

## Kurulum

```bash
./scripts/build_app.sh --install   # /Applications/FlutterRunner.app
```

Geliştirirken `swift run` ya da `open Package.swift` (Xcode) yeterli.

## Kullanım

1. **Proje seç**: `pubspec.yaml` olan klasörü seç (hatırlanır).
2. **Cihaz seç**: açık cihazlar, kapalı iOS simülatörleri ve Android
   emülatörleri listelenir. Kapalı bir cihaz seçilirse **Aç ve Çalıştır**
   önce cihazı açar.
3. **Debug / Profile / Release** seç ve çalıştır.

FVM kullanan projelerde `.fvmrc` içindeki sürüm kullanılır.

## Kısayollar

| İşlem | Pencerede | Her yerden (simülatör/editör odaktayken) |
|---|---|---|
| Run | ⌘R | ⌃⌥↩ |
| Hot Reload | ⌘S | ⌃⌥R |
| Hot Restart | ⇧⌘R | ⌃⌥⇧R |
| Stop | ⌘. | ⌃⌥. |

📌 tuşu pencereyi hep üstte tutar.
