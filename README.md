# Lastik Seri Takip

Lastiklerin üzerindeki harf ve rakamlardan oluşan seri numaralarını kamerayla
okuyup cihazda saklayan Flutter uygulaması. Android ve iOS için geliştirilmiştir.

## Özellikler

- Kamera görüntüsünden seri numarasını cihaz üzerinde ve çevrimdışı okuma
- Değişken uzunluktaki seri numaralarını bulma; okunan kodu düzenleme veya elle girme
- Seri numaralarını yerel olarak kaydetme, listeleme ve silme
- Kayıt listesini Excel (`.xlsx`) dosyası olarak WhatsApp veya diğer paylaşım
  uygulamalarına gönderme
- Aynı seri numarasının tekrar kaydedilmesini önleme

## Geliştirme ortamı

- Flutter SDK: `3.32.1` veya üzeri
- Dart SDK: `3.8.1` veya üzeri
- Android: Android SDK 36 ve NDK `27.0.12077973`
- iOS: macOS ve Xcode; en düşük iOS hedefi `15.5`

## Çalıştırma

```sh
flutter pub get
flutter run
```

## Test ve derleme

```sh
flutter analyze
flutter test
flutter build apk --debug
```

iOS uygulamasını macOS üzerinde derlemek için:

```sh
cd ios
pod install
cd ..
flutter build ios
```
