import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audit_model.dart';
import 'storage_service.dart';
import 'audit_question_resolver.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';

class PdfService {
  static String toTurkishUpper(String input) {
    final upper = input.split('').map((char) {
      switch (char) {
        case 'i':
          return 'İ';
        case 'ı':
          return 'I';
        case 'ş':
          return 'Ş';
        case 'ğ':
          return 'Ğ';
        case 'ü':
          return 'Ü';
        case 'ö':
          return 'Ö';
        case 'ç':
          return 'Ç';
        default:
          return char.toUpperCase();
      }
    }).join();
    if (RegExp(r'[ÖÜĞŞÇ]').hasMatch(upper)) {
      return upper.replaceAll('I', 'İ');
    }
    return upper;
  }

  static Future<void> exportAndShareAudit(AuditModel audit, {String? resolvedAuditorName}) async {
    try {
      final pdf = pw.Document();

      final startedStr = audit.startedAt != null ? DateFormat('HH:mm').format(audit.startedAt!) : '-';
      final completedStr = audit.completedAt != null ? DateFormat('HH:mm').format(audit.completedAt!) : '-';
      String durationStr = '-';
      if (audit.startedAt != null && audit.completedAt != null) {
        final diff = audit.completedAt!.difference(audit.startedAt!);
        durationStr = '${diff.inMinutes} Dk';
      }

      // Load local Turkish-supporting font for INSTANT generation (no network requests)
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = ttf; // Using regular for bold as well to save size/time


      Future<pw.Widget?> downloadAndBuildImageWidget(String path) async {
        if (path.isEmpty) return null;
        try {
          if (path.startsWith('http')) {
            try {
              final imageUrl = StorageService.optimizedImageUrl(path);
              debugPrint('PdfService: downloading image $imageUrl');
              final resp = await http.get(Uri.parse(imageUrl));
              if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                final imgBytes = Uint8List.fromList(resp.bodyBytes);
                final image = pw.MemoryImage(imgBytes);
                return pw.Container(
                  width: PdfPageFormat.a4.availableWidth * 0.25,
                  height: 56,
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                );
              }
            } catch (e) {
              debugPrint('PdfService: image download failed: $e');
            }
          } else if (path.startsWith('assets/')) {
            try {
              final data = await rootBundle.load(path);
              final imgBytes = data.buffer.asUint8List();
              if (imgBytes.isNotEmpty) {
                final image = pw.MemoryImage(imgBytes);
                return pw.Container(
                  width: PdfPageFormat.a4.availableWidth * 0.25,
                  height: 56,
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                );
              }
            } catch (e) {
              debugPrint('PdfService: asset image failed: $e');
            }
          } else {
            try {
              final file = File(path);
              if (file.existsSync()) {
                final bytes = file.readAsBytesSync();
                if (bytes.isNotEmpty) {
                  final image = pw.MemoryImage(bytes);
                  return pw.Container(
                    width: PdfPageFormat.a4.availableWidth * 0.25,
                    height: 56,
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  );
                }
              }
            } catch (e) {
              debugPrint('PdfService: local image failed: $e');
            }
          }
        } catch (e) {
          debugPrint('PdfService: error processing image $path: $e');
        }
        return null;
      }

      // Preload images per answer - small and uniform size
      final Map<String, List<pw.Widget>> answerImages = {};
      final Map<String, pw.Widget> additionalNcImages = {};

      for (var ans in audit.answers) {
        final widgets = <pw.Widget>[];
        for (var path in ans.allPhotoUrls) {
          final w = await downloadAndBuildImageWidget(path);
          if (w != null) widgets.add(w);
        }
        answerImages[ans.questionId] = widgets;

        for (var nc in ans.additionalNonconformities) {
          if (nc.photoUrl.isNotEmpty) {
            final w = await downloadAndBuildImageWidget(nc.photoUrl);
            if (w != null) {
              additionalNcImages[nc.id] = w;
            }
          }
        }
      }

      // Build PDF - multi page for full content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text((!kIsWeb && Platform.isIOS) ? 'DENETİM SİSTEMİ RAPORU' : 'METRO İSTANBUL DENETİM RAPORU',
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          font: ttf)),
                  pw.Text(DateFormat('dd.MM.yyyy').format(audit.date),
                      style: pw.TextStyle(font: ttf, fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey900,
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 56,
                        height: 56,
                        decoration: pw.BoxDecoration(
                          color: _getLinePdfColor(audit.line),
                          shape: pw.BoxShape.circle,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          audit.line.toUpperCase(),
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(toTurkishUpper(audit.station), style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blueGrey900,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                            child: pw.Text(
                              audit.auditType.toUpperCase(),
                              style: pw.TextStyle(
                                font: ttf,
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue300,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text('Denetim ID: ${audit.id.replaceAll('AUD', 'DNT')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blueGrey200)),
                          pw.Text('Tarih: ${DateFormat('dd.MM.yyyy').format(audit.date)}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blueGrey200)),
                          pw.Text('Süre: $startedStr - $completedStr ($durationStr)', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blueGrey200)),
                          pw.Text('Denetçi: ${resolvedAuditorName ?? audit.auditorName}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blueGrey200)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: audit.score >= 85 ? PdfColors.green700 : (audit.score >= 70 ? PdfColors.orange700 : PdfColors.red700),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('BAŞARI SKORU', style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                             pw.Text('%${audit.score % 1 == 0 ? audit.score.toInt().toString() : audit.score.toStringAsFixed(1)}', style: pw.TextStyle(font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ]
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Tür: ${audit.auditType}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blueGrey200)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            // Category chart at the top (horizontal bar chart) - 100 points scale
            pw.Text('KATEGORİ BAŞARI ANALİZİ (100 Puan Üzerinden)',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    font: ttf)),
            pw.SizedBox(height: 8),
            _buildCategoryChart(audit, ttf),
            pw.SizedBox(height: 20),
            pw.Text('DENETİM SORULARI VE CEVAPLAR',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    font: ttf)),
            pw.Divider(),
            ...AuditQuestionResolver.groupByCategory(audit).expand((section) {
              return [
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  color: PdfColors.blueGrey100,
                  child: pw.Text(section.categoryName.toUpperCase(),
                      style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                ),
                ...section.items.map((item) {
              final ans = item.answer;
              final q = item.question;
              final index = audit.answers.indexWhere((a) => a.questionId == ans.questionId);
              final questionNumber = index + 1;
              final isNc = ans.isNonconformity;
              final statusColor = isNc ? PdfColors.red800 : PdfColors.green800;
              final headerBgColor = isNc ? PdfColors.red800 : PdfColors.green800;
              const headerTextColor = PdfColors.white;
              
              return pw.Column(
                  children: [
                  pw.Container(
                    width: double.infinity,
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Soru Yazısı - Yatay Renkli Kısım
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: headerBgColor,
                            border: pw.Border.all(color: PdfColors.black, width: 1.0),
                          ),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Soru #$questionNumber:', style: pw.TextStyle(font: ttf, fontSize: 10, color: headerTextColor, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(width: 6),
                              pw.Expanded(
                                child: pw.Text('${q.categoryName}: ${q.questionText}',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf, fontSize: 10, color: headerTextColor)),
                              ),
                            ],
                          ),
                        ),
                        // Cevap ve Değerlendirme - Standart Alt Kutu
                        pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border(
                              left: pw.BorderSide(color: PdfColors.black, width: 1.0),
                              right: pw.BorderSide(color: PdfColors.black, width: 1.0),
                              bottom: pw.BorderSide(color: PdfColors.black, width: 1.0),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    ans.isOutOfScope ? 'Değerlendirme: KAPSAM DIŞI' : 'Değerlendirme: ${isNc ? 'UYGUNSUZ' : 'UYGUN'}',
                                    style: pw.TextStyle(
                                      color: ans.isOutOfScope ? PdfColors.grey700 : statusColor,
                                      font: ttf,
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold
                                    )
                                  ),
                                  pw.Text(
                                    ans.isOutOfScope ? 'Puan: K.D.' : 'Puan: ${ans.score}/5',
                                    style: pw.TextStyle(
                                      font: ttf,
                                      fontSize: 10,
                                      color: PdfColors.grey700,
                                      fontWeight: pw.FontWeight.bold
                                    )
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 8),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                decoration: pw.BoxDecoration(color: PdfColors.grey50, border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                                child: pw.Row(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Not: ', style: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                                    pw.Expanded(child: pw.Text(
                                      (ans.comment != null && ans.comment!.trim().isNotEmpty)
                                          ? ans.comment!.trim()
                                          : 'Belirtilmedi',
                                      style: pw.TextStyle(
                                        font: ttf, 
                                        fontSize: 9, 
                                        color: (ans.comment != null && ans.comment!.trim().isNotEmpty)
                                            ? PdfColors.black
                                            : PdfColors.grey600
                                      )
                                    )),
                                  ]
                                )
                              ),
                              if (answerImages.containsKey(ans.questionId) && answerImages[ans.questionId]!.isNotEmpty) ...[
                                pw.SizedBox(height: 8),
                                pw.Text('Fotoğraflar:', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                pw.SizedBox(height: 6),
                                pw.Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: answerImages[ans.questionId]!,
                                ),
                              ],
                              if (ans.additionalNonconformities.isNotEmpty) ...[
                                pw.SizedBox(height: 8),
                                pw.Text('İlave Uygunsuzluklar:', style: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                                pw.SizedBox(height: 4),
                                ...ans.additionalNonconformities.map((nc) {
                                  final imgWidget = additionalNcImages[nc.id];
                                  return pw.Container(
                                    margin: const pw.EdgeInsets.only(bottom: 6),
                                    padding: const pw.EdgeInsets.all(6),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.grey50,
                                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                                    ),
                                    child: pw.Row(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        if (imgWidget != null) ...[
                                          imgWidget,
                                          pw.SizedBox(width: 8),
                                        ],
                                        pw.Expanded(
                                          child: pw.Column(
                                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                                            children: [
                                              pw.Text('Açıklama:', style: pw.TextStyle(font: ttf, fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                                              pw.SizedBox(height: 2),
                                              pw.Text(nc.comment, style: pw.TextStyle(font: ttf, fontSize: 8.5)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
                }),
              ];
            }),
            pw.SizedBox(height: 15),
          ],
        ),
      );

      debugPrint('PdfService: PDF built, saving...');
      final bytes = await pdf.save();
      debugPrint('PdfService: PDF saved, ${bytes.length} bytes');

      final safeFileName = '${audit.line}_${audit.station}_${DateFormat('dd_MM_yyyy').format(audit.date)}_Denetim_Raporu.pdf'.replaceAll(' ', '_');

      if (kIsWeb) {
        debugPrint('PdfService: sharing PDF on web...');
        await Printing.sharePdf(bytes: bytes, filename: safeFileName);
        debugPrint('PdfService: PDF shared successfully');
      } else {
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/$safeFileName");
        await file.writeAsBytes(bytes);
        debugPrint('PdfService: PDF saved to ${file.path}');
        await Share.shareXFiles([XFile(file.path)],
            text: '${audit.line} ${audit.station} Metro İstanbul Denetim Raporu');
      }
    } catch (e, stack) {
      debugPrint('PdfService: ERROR: $e\n$stack');
      rethrow;
    }
  }

  // Build a simple bar chart for category scores (out of 100)
  static pw.Widget _buildCategoryChart(AuditModel audit, pw.Font ttf) {
    debugPrint('PdfService: building category chart...');
    // Group answers by category
    final categoryAnswers = <String, List<AuditAnswer>>{};
    final categoryNames = <String, String>{};
    for (var item in AuditQuestionResolver.resolveAnswers(audit)) {
      final ans = item.answer;
      final q = item.question;
      final cat = q.categoryName;
      categoryNames[cat] = q.categoryName;
      categoryAnswers.putIfAbsent(cat, () => <AuditAnswer>[]).add(ans);
    }

    final widgets = <pw.Widget>[];
    // Calculate maximum bar width based on available page width
    final maxBarWidth = PdfPageFormat.a4.availableWidth * 0.6;
    categoryAnswers.forEach((cat, answersList) {
      final activeAnswers = answersList.where((a) => a.isOutOfScope != true).toList();
      final avgPercent = activeAnswers.isEmpty
          ? 100.0
          : activeAnswers.fold<double>(0.0, (sum, a) => sum + a.normalizedScore) / activeAnswers.length;
      final barWidth = (avgPercent / 100 * maxBarWidth).clamp(10.0, maxBarWidth);
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 100,
                child: pw.Text(categoryNames[cat]!, 
                    style: pw.TextStyle(font: ttf, fontSize: 9)),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                height: 12,
                width: barWidth,
                decoration: pw.BoxDecoration(
                  color: avgPercent >= 80 ? PdfColors.green : (avgPercent >= 60 ? PdfColors.orange : PdfColors.red),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text('${avgPercent.toStringAsFixed(0)}/100', 
                  style: pw.TextStyle(font: ttf, fontSize: 9)),
            ],
          ),
        ),
      );
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static Future<void> shareToWhatsApp(AuditModel audit) async {
    String reportTitle = (!kIsWeb && Platform.isIOS) ? '*DENETİM SİSTEMİ RAPORU*' : '*METRO İSTANBUL DENETİM RAPORU*';
    String text = "$reportTitle\n\n"
        "*ID:* ${audit.id}\n"
        "*Hat/İstasyon:* ${audit.line} / ${audit.station}\n"
        "*Denetçi:* ${audit.auditorName}\n"
        "*Skor:* %${audit.score % 1 == 0 ? audit.score.toInt().toString() : audit.score.toStringAsFixed(1)}\n"
        "*Tarih:* ${DateFormat('dd.MM.yyyy HH:mm').format(audit.date)}\n\n"
        "*Uygunsuzluklar:*\n";

    final ncs = audit.answers.where((a) => a.isNonconformity).toList();
    if (ncs.isEmpty) {
      text += "Uygunsuzluk tespit edilmedi.";
    } else {
      for (var nc in ncs) {
        final q = AuditQuestionResolver.resolveAnswer(audit, nc).question;
        text += "- ${q.questionText}: ${nc.comment ?? 'Not yok'}\n";
      }
    }

    // Fotoğrafları paylaş
    List<XFile> files = [];
    for (var ans in audit.answers) {
      if (ans.allPhotoUrls.isNotEmpty) {
        for (var path in ans.allPhotoUrls) {
          if (path.startsWith('http')) {
            // Mock URL'ler için gerçek dosyaya ihtiyacımız var ama bu ortamda indiremeyiz.
          } else {
            files.add(XFile(path));
          }
        }
      }
    }

    if (files.isNotEmpty && !kIsWeb) {
      try {
        await Share.shareXFiles(files, text: text);
        return;
      } catch (e) {
        debugPrint('PdfService: Share.shareXFiles failed: $e');
      }
    }
    
    // WhatsApp'ı doğrudan açmaya çalış
    final encodedText = Uri.encodeComponent(text);
    final url = Uri.parse("https://api.whatsapp.com/send?text=$encodedText");
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to normal share
        await Share.share(text);
      }
    } catch (e) {
      debugPrint('PdfService: WhatsApp launch failed: $e');
      await Share.share(text);
    }
  }

  static pw.Widget _buildInfoRow(String label, String value, pw.Font ttf, {bool isRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: isRight ? [
          pw.Text(value, style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 4),
          pw.Text(label, style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
        ] : [
          pw.Text(label, style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(width: 4),
          pw.Text(value, style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static PdfColor _getLinePdfColor(String line) {
    switch (line.toUpperCase()) {
      case 'M1':
      case 'M1A':
      case 'M1B':
        return PdfColor.fromHex('#E31E24');
      case 'M2':
        return PdfColor.fromHex('#009543');
      case 'M3':
        return PdfColor.fromHex('#009FE3');
      case 'M4':
        return PdfColor.fromHex('#E91E63');
      case 'M5':
        return PdfColor.fromHex('#673AB7');
      case 'M6':
        return PdfColor.fromHex('#C7B299');
      case 'M7':
        return PdfColor.fromHex('#FF4081');
      case 'M8':
        return PdfColor.fromHex('#00BCD4');
      case 'M9':
        return PdfColor.fromHex('#FFD54F');
      case 'M11':
        return PdfColor.fromHex('#9E9E9E');
      case 'T1':
        return PdfColor.fromHex('#0054A6');
      case 'T4':
        return PdfColor.fromHex('#F07D00');
      case 'T5':
        return PdfColor.fromHex('#00A651');
      case 'F1':
      case 'F4':
        return PdfColor.fromHex('#795548');
      case 'TF1':
      case 'TF2':
        return PdfColor.fromHex('#009688');
      default:
        return PdfColor.fromHex('#64748B');
    }
  }
}
