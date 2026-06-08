import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifre Değiştir')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Yeni Şifre', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Yeni Şifre (Tekrar)', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifreniz başarıyla değiştirildi.')));
                context.pop();
              },
              child: const Text('Şifreyi Güncelle'),
            ),
          ],
        ),
      ),
    );
  }
}

