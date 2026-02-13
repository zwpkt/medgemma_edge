import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medgemma_go/features/chat/services/llama_service.dart';
import 'package:medgemma_go/features/chat/services/storage_service.dart';

final sl = GetIt.instance;

Future<void> setupInjection() async {
  // 外部依赖
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // 业务服务
  sl.registerLazySingleton<StorageService>(() => StorageService(sl()));
  sl.registerLazySingleton<LlamaService>(() => LlamaService());

  // 初始化模型加载状态
  await sl<LlamaService>().loadMultimodalModel();
}