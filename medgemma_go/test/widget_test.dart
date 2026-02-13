import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medgemma_go/main.dart';  // 导入您的 main.dart
import 'package:get_it/get_it.dart';
import 'package:medgemma_go/features/chat/services/llama_service.dart';
import 'package:medgemma_go/features/chat/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  // ✅【关键】为测试环境设置依赖注入
  setUpAll(() async {
    // 模拟 SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // 注册测试用的服务
    GetIt.I.registerSingleton<SharedPreferences>(prefs);
    GetIt.I.registerLazySingleton<StorageService>(() => StorageService(GetIt.I()));
    GetIt.I.registerLazySingleton<LlamaService>(() => LlamaService());
  });

  testWidgets('MedGemma 应用启动测试', (WidgetTester tester) async {
    // ✅ 改为 MedGemmaApp，不是 MyApp！
    await tester.pumpWidget(const MedGemmaApp());

    // 等待一帧让 UI 构建完成
    await tester.pumpAndSettle();

    // 验证 AppBar 标题是否正确
    expect(find.text('MedGemma 医疗助手'), findsOneWidget);
  });

  // ✅ 清理测试后的依赖
  tearDownAll(() {
    GetIt.I.reset();
  });
}