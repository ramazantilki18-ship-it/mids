// Yapılandırma Ayarları: Otomatik Güncelleme

class UpdateConfig {
  // GitHub kullanıcı adınız
  static const String githubOwner = 'ramazantilki18-ship-it';

  // GitHub repository (depo) adınız
  static const String githubRepo = 'mids';

  // GitHub Release içerisindeki indirilecek APK dosyasının adı
  // (flutter build apk --release --split-per-abi komutuyla üretilen en yaygın APK dosyasının adı)
  static const String apkFileName = 'app-arm64-v8a-release.apk';

  // API Adresi
  static String get latestReleaseUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
}
