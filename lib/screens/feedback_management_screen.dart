import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/feedback_provider.dart';
import '../theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class FeedbackManagementScreen extends StatelessWidget {
  const FeedbackManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geri Bildirim Takip', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Consumer<FeedbackProvider>(
        builder: (context, feedbackProvider, child) {
          if (feedbackProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final feedbacks = feedbackProvider.feedbacks;

          if (feedbacks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Theme.of(context).disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz geri bildirim bulunmuyor.',
                    style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: feedbacks.length,
            itemBuilder: (context, index) {
              final fb = feedbacks[index];
              Color catColor = Colors.blue;
              if (fb.category == 'Hata Bildirimi') catColor = AppColors.accentRed;
              if (fb.category == 'Öneri') catColor = AppColors.accentGreen;
              if (fb.category == 'Soru') catColor = AppColors.accentOrange;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: catColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              fb.category,
                              style: TextStyle(color: catColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(fb.createdAt),
                            style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        fb.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fb.description,
                        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.person_rounded, size: 14, color: Theme.of(context).disabledColor),
                          const SizedBox(width: 4),
                          Text(
                            fb.reporterName,
                            style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (fb.imageUrl != null && fb.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: InteractiveViewer(
                                  child: kIsWeb
                                      ? Image.network(fb.imageUrl!)
                                      : Image.file(File(fb.imageUrl!)), // Note: Cloudinary URLs are always network urls, but just in case
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              fb.imageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(height: 120, color: Colors.grey, child: const Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}