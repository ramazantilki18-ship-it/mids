import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../models/audit_model.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/audit_type_model.dart';
import 'dart:math';

class MockData {
  static final List<UserModel> users = [
    UserModel(id: '1', username: 'ramazan.tilki', role: UserRole.superAdmin, authorizedLines: []),
    UserModel(id: '2', username: 'Mehmet Yılmaz', role: UserRole.fieldAuditor, authorizedLines: ['M1']),
    UserModel(id: '3', username: 'Ayşe Demir', role: UserRole.fieldAuditorActionOwner, authorizedLines: ['M4', 'T1']),
    UserModel(id: '4', username: 'Caner Özcan', role: UserRole.approver, authorizedLines: ['M3', 'M5']),
    UserModel(id: '5', username: 'Fatma Kaya', role: UserRole.executiveViewerRestricted, authorizedLines: []),
  ];

  static final List<String> lines = [
    'M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'M7', 'M8', 'M9',
    'T1', 'T4', 'T5',
    'F1',
    'TF1', 'TF2'
  ];

  // Hat adı -> Renk kodu (hex string)
  static final Map<String, String> linesWithColors = {
    'M1': '0xFFE31E24',
    'M2': '0xFF009543',
    'M3': '0xFF009FE3',
    'M4': '0xFFE91E63',
    'M5': '0xFF9C27B0',
    'M6': '0xFFB9A15E',
    'M7': '0xFFF29100',
    'M8': '0xFF003D88',
    'M9': '0xFFEDD500',
    'T1': '0xFF003D88',
    'T4': '0xFFF29100',
    'T5': '0xFF9C27B0',
    'F1': '0xFF333333',
    'TF1': '0xFF795548',
    'TF2': '0xFF795548',
  };

  static final Map<String, List<String>> stations = {
    'M1': ['Yenikapı', 'Aksaray', 'Emniyet-Fatih', 'Topkapı-Ulubatlı', 'Bayrampaşa-Maltepe', 'Sağmalcılar', 'Kocatepe', 'Otogar', 'Terazidere', 'Davutpaşa-YTÜ', 'Merter', 'Zeytinburnu', 'Bakırköy-İncirli', 'Bahçelievler', 'Ataköy-Şirinevler', 'Yenibosna', 'DTM-İstanbul Fuar Merkezi', 'Atatürk Havalimanı', 'Esenler', 'Menderes', 'Üçyüzlü', 'Bağcılar Meydan', 'Kirazlı'],
    'M2': ['Yenikapı', 'Vezneciler', 'Haliç', 'Şişhane', 'Taksim', 'Osmanbey', 'Şişli-Mecidiyeköy', 'Gayrettepe', 'Levent', '4.Levent', 'Sanayi Mahallesi', 'İTÜ-Ayazağa', 'Atatürk Oto Sanayi', 'Darüşşafaka', 'Hacıosman'],
    'M3': ['Kirazlı', 'Yenimahalle', 'Mahmutbey', 'İSTOÇ', 'İkitelli Sanayi', 'Turgut Özal', 'Siteler', 'Başak Konutları', 'MetroKent'],
    'M4': ['Kadıköy', 'Ayrılık Çeşmesi', 'Acıbadem', 'Ünalan', 'Göztepe', 'Yenisahra', 'Kozyatağı', 'Bostancı', 'Küçükyalı', 'Maltepe', 'Huzurevi', 'Gülsuyu', 'Esenkent', 'Hastane-Adliye', 'Soğanlık', 'Kartal', 'Yakacık', 'Pendik', 'Tavşantepe', 'Sabiha Gökçen Havalimanı'],
    'M5': ['Üsküdar', 'Fıstıkağacı', 'Bağlarbaşı', 'Altunizade', 'Kısıklı', 'Bulgurlu', 'Ümraniye', 'Çarşı', 'Yamanevler', 'Çakmak', 'Ihlamurkuyu', 'Altınşehir', 'İmam Hatip Lisesi', 'Dudullu', 'Necip Fazıl', 'Çekmeköy'],
    'M6': ['Levent', 'Nispetiye', 'Etiler', 'Boğaziçi Üni.'],
    'M7': ['Mecidiyeköy', 'Çağlayan', 'Kağıthane', 'Nurtepe', 'Alibeyköy', 'Çırçır', 'Veysel Karani', 'Yeşilpınar', 'Kazım Karabekir', 'Yenimahalle', 'Karadeniz Mahallesi', 'Giyimkent-Tekstilkent', 'Yüzyıl-Oruç Reis', 'Göztepe Mahallesi', 'Mahmutbey'],
    'M8': ['Bostancı', 'Emin Ali Paşa', 'Ayşekadın', 'Kozyatağı', 'Küçükbakkalköy', 'İçerenköy', 'Kayışdağı', 'Mevlana', 'İMES', 'MODOKO', 'Dudullu', 'Parseller'],
    'M9': ['Olimpiyat', 'Ziya Gökalp', 'İkitelli Sanayi', 'Masko', 'Bahariye', 'Ataköy', 'Yenibosna'],
    'T1': ['Kabataş', 'Fındıklı', 'Tophane', 'Karaköy', 'Eminönü', 'Sirkeci', 'Gülhane', 'Sultanahmet', 'Çemberlitaş', 'Beyazıt', 'Laleli', 'Aksaray', 'Yusufpaşa', 'Haseki', 'Fındıkzade', 'Pazartekke', 'Topkapı', 'Cevizlibağ', 'Merter Tekstil', 'Güngören', 'Bağcılar'],
    'T4': ['Topkapı', 'Fetihkapı', 'Vatan', 'Edirnekapı', 'Şehitlik', 'Demirkapı', 'Rami', 'Uluyol', 'Bereç', 'Sağmalcılar', 'Bosna-Çukurçeşme', 'Habibler'],
    'T5': ['Eminönü', 'Küçükpazar', 'Cibali', 'Fener', 'Balat', 'Ayvansaray', 'Feshane', 'Eyüpsultan Teleferik', 'Eyüpsultan Devlet Hast.', 'Silahtarağa', 'Alibeyköy'],
    'F1': ['Taksim', 'Kabataş'],
    'TF1': ['Maçka', 'Taşkışla'],
    'TF2': ['Eyüp', 'Piyer Loti'],
  };

  static final List<QuestionGroupModel> questionGroups = [
    QuestionGroupModel(id: 'g1', auditTypeId: AuditTypeModel.fiveSId, name: '5S Denetimi', icon: Icons.fact_check_rounded),
  ];

  static final List<QuestionModel> questions = [
    QuestionModel(id: 'q1', groupId: 'g1', categoryName: 'SINIFLANDIRMA', questionText: 'Fazla Sarf Malzeme /Ekipman var mı?', orderIndex: 0),
    QuestionModel(id: 'q2', groupId: 'g1', categoryName: 'SINIFLANDIRMA', questionText: 'Fazla Demirbaş var mı?', orderIndex: 1),
    QuestionModel(id: 'q3', groupId: 'g1', categoryName: 'SINIFLANDIRMA', questionText: 'Kullanılmayan Malzeme/Ekipman/Doküman var mı?', orderIndex: 2),
    QuestionModel(id: 'q4', groupId: 'g1', categoryName: 'SINIFLANDIRMA', questionText: 'İşlevini Yitirmiş Malzeme/Ekipman/Doküman/İlk Yardım Çan. var mı?', orderIndex: 3),
    QuestionModel(id: 'q5', groupId: 'g1', categoryName: 'SINIFLANDIRMA', questionText: 'Ulaşılamayan oda, bölge veya alan var mı? (Kilitli odalar için kilitler Sor odasında bulunuyor mu?)', orderIndex: 4),
    QuestionModel(id: 'q6', groupId: 'g1', categoryName: 'SINIFLANDIRMA', questionText: 'Karantina alanına ihtiyaç var mı? Karantina alanı mevcut mu? Gereksiz/Fazla Malzeme ve ekipmanın kaydı tutulmuş mu?', orderIndex: 5),
    
    QuestionModel(id: 'q7', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Yeri belli olmayan malzeme ekipman vb. var mı?', orderIndex: 6),
    QuestionModel(id: 'q8', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Yeri uygun olmayan malzeme ekipman vb. var mı?', orderIndex: 7),
    QuestionModel(id: 'q9', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Dekota / etiket çalışması yapılmış mı?', orderIndex: 8),
    QuestionModel(id: 'q10', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Temizlik Dolabı içinin Etiketleri var mı?', orderIndex: 9),
    QuestionModel(id: 'q11', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Anahtarlık Dolabı içinin Etiketleri var mı?', orderIndex: 10),
    QuestionModel(id: 'q12', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Acil Müdahale Dolabı içinin etiketleri var mı?', orderIndex: 11),
    QuestionModel(id: 'q13', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Soyunma Dolabı Etiketleri var mı?', orderIndex: 12),
    QuestionModel(id: 'q14', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Diğer Dolap içi Etiketleri var mı?', orderIndex: 13),
    QuestionModel(id: 'q15', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Yer çizgisi çalışması ile alan belirlenmesi yapılmış mı?', orderIndex: 14),
    QuestionModel(id: 'q16', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Stoklamaya önden başlama, farklı ürünlerin ayırt edilmesi, zemine direkt ekipman bırakılmaması (palet vb.), yer tahsisinde derinlik ve yükseklik dikkate alınması kriterleri sağlanıyor mu?', orderIndex: 15),
    QuestionModel(id: 'q17', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Temizlik malzemeleri ayrı dolaplarda ve uygun şekilde muhafaza ediliyor mu?', orderIndex: 16),
    QuestionModel(id: 'q18', groupId: 'g1', categoryName: 'SIRALAMA', questionText: 'Temizlik malzeme etiketleri ve Güvenlik Bilgi Formları (MSDS) var mı?', orderIndex: 17),

    QuestionModel(id: 'q19', groupId: 'g1', categoryName: 'SİLME', questionText: 'Zemin temiz tutuluyor ve akışkan maddelerin yerlere akmaması için gerekliyse koruyucu önlemler alınıyor mu?', orderIndex: 18),
    QuestionModel(id: 'q20', groupId: 'g1', categoryName: 'SİLME', questionText: 'Ekipmanlar, malzemeler temiz tutuluyor mu?', orderIndex: 19),
    QuestionModel(id: 'q21', groupId: 'g1', categoryName: 'SİLME', questionText: 'Duvarlar, kolonlar, korkuluklar, panolar, YM ve Asansörler vb. boyalı ve/veya temiz tutuluyor mu?', orderIndex: 20),

    QuestionModel(id: 'q22', groupId: 'g1', categoryName: 'STANDARTLAŞTIRMA', questionText: 'İstasyon Kat Planları var mı?', orderIndex: 21),
    QuestionModel(id: 'q23', groupId: 'g1', categoryName: 'STANDARTLAŞTIRMA', questionText: 'Temizlik Odası Planları var mı?', orderIndex: 22),
    QuestionModel(id: 'q24', groupId: 'g1', categoryName: 'STANDARTLAŞTIRMA', questionText: 'Dinlenme Odası Planı var mı?', orderIndex: 23),
    QuestionModel(id: 'q25', groupId: 'g1', categoryName: 'STANDARTLAŞTIRMA', questionText: 'İstasyon Amirliği Odası Planı var mı?', orderIndex: 24),
    QuestionModel(id: 'q26', groupId: 'g1', categoryName: 'STANDARTLAŞTIRMA', questionText: 'Varsa Diğer Odaların Planı Var mı? (İlk yardım, makinist, bebek bakım odası vb.)', orderIndex: 25),
    QuestionModel(id: 'q27', groupId: 'g1', categoryName: 'STANDARTLAŞTIRMA', questionText: 'Acil Müdahale Dolabı Planı var mı?', orderIndex: 26),
    QuestionModel(id: 'q28', groupId: 'g1', categoryName: 'STANDARTLAŞTIRMA', questionText: 'Temizlik Dolabı planı var mı?', orderIndex: 27),
    QuestionModel(id: 'q29', groupId: 'g1', categoryName: 'STANDARTLAŞTIRMA', questionText: 'Anahtarlık Dolabı Planı var mı?', orderIndex: 28),
    QuestionModel(id: 'q30', groupId: 'g1', categoryName: 'STANDARTLAŞTIRMA', questionText: 'İyileştirme panosu mevcut ve pano içinde olması gereken dökümanlar bulunuyor mu? (İstasyon denetim sorumlusu, Denetim Kontrol Formu, önce/sonra fotoğrafları vb.)', orderIndex: 29),

    QuestionModel(id: 'q31', groupId: 'g1', categoryName: 'SAHİPLENME', questionText: 'Tutum ve davranışlar denetim yaklaşımının faydalarının anlaşıldığını gösteriyor mu?', orderIndex: 30),
    QuestionModel(id: 'q32', groupId: 'g1', categoryName: 'SAHİPLENME', questionText: 'denetim standartlarını uygularken israflardan kaçınılmış mı?', orderIndex: 31),
    QuestionModel(id: 'q33', groupId: 'g1', categoryName: 'SAHİPLENME', questionText: 'denetim çalışması yaparken örnek alınacak uygulamalar geliştiriliyor mu?', orderIndex: 32),
  ];

  // Yerel örnek fotoğraflar (assets/images/ altında)
  static const List<String> realPhotos = [
    'assets/images/sample1.jpg',
    'assets/images/sample3.jpg',
    'assets/images/logo.png',
    'assets/images/login_bg.jpg',
  ];

  // ──────────── GERÇEKÇE UYGUNSUZLUK YORUMLARI ────────────
  static const List<String> _ncCommentsAyiklama = [
    'Peron alanında kullanılmayan eski kablolar ve yedek tüpler bulunmaktadır. Acilen toplanması gerekmektedir.',
    'Teknik odada arızalı UPS cihazı ve deforme olmuş kasa parçaları hâlâ rafta duruyor, uzaklaştırılmamış.',
    'Personel soyunma odasında kırık sandalyeler ve kullanım dışı kıyafet askılıkları birikmiş, ayıklanmamış.',
    'İstasyon deposunda son kullanma tarihi geçmiş temizlik malzemeleri tespit edildi.',
  ];

  static const List<String> _ncCommentsDuzen = [
    'Yangın söndürme tüpünün önü malzeme kutuları ile kapatılmış, acil erişim sağlanamıyor.',
    'Elektrik panosu üzerinde etiketleme yapılmamış, hangi şalterin hangi devreye ait olduğu belli değil.',
    'Ekipman dolabındaki malzemeler karmaşık şekilde istiflenmiş, yer işaretleri silinmiş durumda.',
    'İlk yardım dolabının yeri standart dışı, levha ile gösterilmemiş.',
  ];

  static const List<String> _ncCommentsTemizlik = [
    'Peron zemini üzerinde yağlı lekeler var, yolcu güvenliğini tehdit ediyor. Kayma riski mevcut.',
    'Havalandırma ızgaralarında yoğun toz birikimi tespit edildi, bakım planına dahil edilmeli.',
    'Tuvalet alanında hijyen standartları karşılanmıyor, zemin ıslak ve temizlik malzemesi eksik.',
    'Yürüyen merdiven basamaklarında sakız kalıntıları ve yapışkan izler mevcut.',
  ];

  static const List<String> _ncCommentsStandart = [
    'Yönlendirme levhaları solmuş ve okunamaz halde, yenilenmesi acil ihtiyaç.',
    'Acil çıkış işaretlerinin 2 tanesi yanmıyor, elektrik bağlantısı kontrol edilmeli.',
    'Zemin işaretleme bantları yıpranmış ve birçok noktada kopmuş, standardı karşılamıyor.',
    'Güvenlik kamera kayıt uyarı levhası eksik, KVKK uyumu sağlanmamış.',
  ];

  static const List<String> _ncCommentsDisiplin = [
    'Personel denetim kontrol formunu 3 haftadır doldurmamış, denetim takibi yapılmıyor.',
    'Vardiya teslim defteri eksik doldurulmuş, notlar okunaksız ve imzasız.',
    'Personel iş güvenliği ekipmanlarını (baret, yelek) kullanmadan sahada çalışıyor.',
    'Temizlik çizelgesi güncel değil, son 2 haftanın kayıtları boş bırakılmış.',
  ];

  static const List<String> _successComments = [
    'Alan son derece düzenli, tüm malzemeler etiketli ve yerinde. Örnek bir istasyon.',
    'Zemin tertemiz, ekipmanlar bakımlı. Personel kurumsal denetim bilincinde çalışıyor.',
    'Acil durum ekipmanları eksiksiz ve erişilebilir durumda. Levhalar güncel.',
    'Mükemmel düzende bir teknik oda. Kablolama düzgün, etiketler okunaklı.',
    'Personel vardiya teslim defterini eksiksiz dolduruyor. Denetim formları güncel.',
    'İstasyon genelinde çok iyi bir temizlik standardı yakalanmış, tebrikler.',
  ];

  // ──────────── DENETİM GEÇMİŞİ ÜRETİCİ ────────────

  static String _getNcComment(String category, Random r) {
    if (category.contains('SINIFLANDIRMA')) return _ncCommentsAyiklama[r.nextInt(_ncCommentsAyiklama.length)];
    if (category.contains('SIRALAMA')) return _ncCommentsDuzen[r.nextInt(_ncCommentsDuzen.length)];
    if (category.contains('SİLME')) return _ncCommentsTemizlik[r.nextInt(_ncCommentsTemizlik.length)];
    if (category.contains('STANDARTLAŞTIRMA')) return _ncCommentsStandart[r.nextInt(_ncCommentsStandart.length)];
    return _ncCommentsDisiplin[r.nextInt(_ncCommentsDisiplin.length)];
  }

  static List<AuditModel> _generateAuditHistory() {
    final List<AuditModel> history = [];
    final Random r = Random(42); // Sabit seed = her seferinde aynı veri
    final now = DateTime.now();

    // ── 10 adet DÜŞÜK PUANLI denetim (uygunsuzluklu, yakın tarihli) ──
    for (int i = 0; i < 10; i++) {
      final date = now.subtract(Duration(days: i + 1, hours: r.nextInt(12)));
      history.add(_createAudit(i, date, 'low', r));
    }

    // ── 5 adet ORTA PUANLI denetim (kısmen uygunsuzluklu, 1-2 ay öncesi) ──
    for (int i = 10; i < 15; i++) {
      final date = now.subtract(Duration(days: 30 + r.nextInt(30), hours: r.nextInt(12)));
      history.add(_createAudit(i, date, 'medium', r));
    }

    // ── 15 adet YÜKSEK PUANLI denetim (başarılı, çeşitli tarihler) ──
    for (int i = 15; i < 30; i++) {
      final date = now.subtract(Duration(days: r.nextInt(60), hours: r.nextInt(12)));
      history.add(_createAudit(i, date, 'high', r));
    }

    history.sort((a, b) => b.date.compareTo(a.date));
    return history;
  }

  static AuditModel _createAudit(int i, DateTime date, String quality, Random r) {
    final user = users[i % users.length];
    final line = lines[r.nextInt(lines.length)];
    final lineStations = stations[line] ?? ['Merkez İstasyon'];
    final station = lineStations[r.nextInt(lineStations.length)];

    final answers = questions.map((q) {
      int score;
      switch (quality) {
        case 'low':
          // Düşük puanlı: en az 3 soru uygunsuz
          score = (r.nextDouble() < 0.5) ? (r.nextInt(3) + 1) : (r.nextInt(2) + 4);
          if (q.id == '1' || q.id == '5') score = r.nextInt(2) + 1; // İlk ve 5. kesin düşük
          break;
        case 'medium':
          // Orta: 1-2 soru uygunsuz, geri kalanı iyi
          score = (r.nextDouble() < 0.25) ? (r.nextInt(2) + 2) : 5;
          if (q.id == '3') score = 3; // Düzen sorusu biraz düşük
          break;
        default: // high
          score = 5; // Tüm sorular tam puan
          break;
      }

      bool isNC = score <= 3;
      String? comment;
      List<String> photos = [];

      if (isNC) {
        comment = _getNcComment(q.categoryName, r);
        int photoCount = r.nextInt(2) + 1;
        for (int p = 0; p < photoCount; p++) {
          photos.add(realPhotos[r.nextInt(realPhotos.length)]);
        }
      } else if (r.nextDouble() < 0.15) {
        comment = _successComments[r.nextInt(_successComments.length)];
      }

      return AuditAnswer(
        questionId: q.id,
        score: score,
        isNonconformity: isNC,
        comment: comment,
        photoPaths: photos,
      );
    }).toList();

    double calculatedScore = (answers.fold(0.0, (sum, a) => sum + a.score) / (questions.length * 5)) * 100;

    return AuditModel(
      id: 'AUD-${2000 + i}',
      auditorId: user.id,
      auditorName: user.username,
      line: line,
      station: station,
      date: date,
      score: double.parse(calculatedScore.toStringAsFixed(1)),
      auditType: '5S Denetimi',
      isCompleted: true,
      answers: answers,
    );
  }

  static final List<AuditModel> auditHistory = [];

  static final List<TaskModel> assignedTasks = [];
}
