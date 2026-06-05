import 'package:flutter/material.dart';
import 'app.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 端末UUIDを初期化（無ければ生成）
  await AuthService.getUserId();
  runApp(const RegretLensApp());
}
