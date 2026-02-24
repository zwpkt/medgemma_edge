import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import '../../core/constants/model_config.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;


/// Core inference service for MedGemma Edge
/// Based on llama_cpp_dart, supports multimodal and offline inference
class LlamaEdgeService {
  static final LlamaEdgeService _instance = LlamaEdgeService._internal();
  factory LlamaEdgeService() => _instance;
  LlamaEdgeService._internal();

  // ✅ Core: Managed Isolate (Flutter-friendly, non-blocking)
  LlamaParent? _llamaParent;
  LlamaScope? _currentScope;  // ✅ Holds the current request's scope

  // Status
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isModelLoaded => _llamaParent != null;

  // Response Stream
  final _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  // Loading Progress
  final _loadingController = StreamController<double>.broadcast();
  Stream<double> get loadingStream => _loadingController.stream;

  // Error Stream
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  /// Load multimodal model (Core Edge AI)
  Future<bool> loadModel() async {
    try {
      _checkMemory();

      _loadingController.add(0.1);

      // 1. Preload system libraries first
      //_preloadSystemLibs();
      //print("🚀 Native system dependency chain loaded");

      // 2. Then preload your custom compiled libraries (order is important)
      //_preloadYourCustomLibs();

      //print("🚀 Native custom compiled dependency chain loaded");
      _loadingController.add(0.2);

      // 1. Check for model files
      print('🔍 [MedGemma Edge] Checking for model files...');
      final filesExist = await ModelConfig.checkFilesExist();
      if (!filesExist) {
        final adbCmd = await ModelConfig.getAdbPushCommand();
        _errorController.add('Model files not found\n$adbCmd');
        _loadingController.add(-1);
        return false;
      }

      _loadingController.add(0.3);

      // 2. Get model paths
      final textPath = await ModelConfig.textModelPath;
      final mmprojPath = await ModelConfig.mmprojPath;

      print('📦 [MedGemma Edge] Loading configuration:');
      print('   - Text Model: $textPath； size：${File(textPath).lengthSync()}');
      print('   - Projector: $mmprojPath； size：${File(mmprojPath).lengthSync()}');


      // 3. Configure model parameters (Edge AI optimization)
      final loadCommand = LlamaLoad(
        path: textPath,
        modelParams: ModelParams()
          ..nGpuLayers = 0              // 99: Use GPU as much as possible; 0: CPU
          ..mainGpu = -1  // -1 explicitly tells the system not to use any GPU
          ..useMemorymap = true          // ✅ Original useMmap → useMemorymap, true. This allows the Android system to manage memory more flexibly, reducing I/O blocking during loading
          ..useMemoryLock = false        // ✅ Original useMlock → useMemoryLock
          ..checkTensors = false
          ..useExtraBufts = false
          ..noHost = false,
        contextParams: ContextParams()
          ..nCtx = 1024    //2048
          ..nBatch = 512    //Set to 1024. For single-user chat, this provides a stable Time to First Token (TTFT).
          ..nUbatch = 64  // If not set, use system default 512
          ..nThreads = 4
          ..nThreadsBatch = 4
          //..nPredict=256    // Truncates when token limit is exceeded. Use with caution.
          ..nSeqMax = 1,
        samplingParams: SamplerParams()  // ✅ Class name is correct
          ..temp = 0.3        // ✅ A temperature of 0.7 is too high for a medical model. 0.2-0.4 makes the output more deterministic and medically accurate.
          ..topK = 20   // When selecting the next word, only consider the top K most probable words
          ..minP = 0.05 // The probability of any selected word must be at least Min-P times the probability of the most probable word
          ..topP = 0.80 // Whether the "sum of probabilities" of these words has reached topP
          ..penaltyRepeat = 1.2,        // ✅ Increase to 1.15 - 1.2 to prevent repetitive answers.
        mmprojPath: mmprojPath,  // ✅ Multimodal: Pass the projector path!
        verbose: true,
      );

      _loadingController.add(0.6);

      // Key change: Set the static variable before creating LlamaParent; set the main Isolate's libraryPath first
      Llama.libraryPath = 'libllama.so';
      print('📌 [MainIsolate] libraryPath has been set to: libllama.so');

      // 4. Initialize LlamaParent
      print('🚀 [MedGemma Edge] Initializing inference engine...');
      _llamaParent = LlamaParent(loadCommand);
      print('🚀 [MedGemma Edge] Loading model...');

      print(" Llama.libraryPath${ Llama.libraryPath}");
      await _llamaParent!.init();

      print('🚀 [MedGemma Edge] Model loading complete');

      _loadingController.add(0.9);

      //Create scope
      _currentScope=_llamaParent?.getScope();

      _isInitialized = true;
      _loadingController.add(1.0);

      print('✅ [MedGemma Edge] Model loaded successfully!');
      print('   - Device: ${Platform.operatingSystem}');
      print('   - Mode: Fully Offline | GPU Acceleration | Edge Computing');

      return true;
    } catch (e, s) {
      print('❌ [MedGemma Edge] Loading failed: $e\n$s');
      _errorController.add('Loading failed: $e');
      _loadingController.add(-1);
      return false;
    }
  }


  // Add memory check before calling _initializeLlama
  Future<bool> _checkMemory() async {
    try {
      final file = File('/proc/meminfo');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        int memAvailable = 0;
        int memTotal = 0;

        for (final line in lines) {
          if (line.startsWith('MemAvailable:')) {
            memAvailable = int.parse(line.split(RegExp(r'\s+'))[1]) ~/ 1024; // to MB
            print('📊 System available memory: $memAvailable MB');
          } else if (line.startsWith('MemTotal:')) {
            memTotal = int.parse(line.split(RegExp(r'\s+'))[1]) ~/ 1024;
            print('📊 System total memory: $memTotal MB');
          }
        }

        // Model requires about 3GB of free memory
        if (memAvailable < 3000) {
          print('⚠️ Warning: Less than 3GB of available memory, model loading may fail');
          return false;
        }
      }

      // Process memory
      final rss = ProcessInfo.currentRss ~/ (1024 * 1024);
      print('📊 Process current RSS: $rss MB');

      return true;
    } catch (e) {
      print('⚠️ Unable to get memory information: $e');
      return true; // Continue trying
    }
  }


  void _preloadSystemLibs() {
    if (Platform.isAndroid) {
      DynamicLibrary.open('liblog.so');
      DynamicLibrary.open('libm.so');
      DynamicLibrary.open('libdl.so');
    }
  }

  void _preloadYourCustomLibs() {
    // Manually load in dependency order
    DynamicLibrary.open('libc++_shared.so');
    DynamicLibrary.open('libomp.so');
    DynamicLibrary.open('libggml.so');
    DynamicLibrary.open('libggml-base.so');
    DynamicLibrary.open('libggml-cpu.so');
    // Note: libllama.so is usually loaded internally by the plugin, but loading it manually once can expose symbol errors early
    DynamicLibrary.open('libmtmd.so');
    DynamicLibrary.open('libllama.so');

  }

  // It's recommended to define this formatter object as a class member to avoid repeated creation
  final _gemmaFormatter = GemmaFormat(systemPrefix: 'You are a professional doctor. Please answer briefly and avoid nonsense.');

  /// Plain text generation
  void generateText(String prompt) {
    if (!_isInitialized || _llamaParent == null) {
      _errorController.add('Model not initialized');
      return;
    }

    // 4. [Core Improvement]: Use GemmaFormat object to generate standard Prompt
    // It will be automatically wrapped as: <start_of_turn>user\n$prompt<end_of_turn>\n<start_of_turn>model\n
    final String formattedPrompt = _gemmaFormatter.formatPrompt(prompt);
    print('📝 [User] $formattedPrompt');


    // Listen for responses via scope
    _currentScope!.stream.listen(
          (response) {
        _responseController.add(response);
      },
      onError: (error) {
        _errorController.add('Generation error: $error');
      },
      onDone: () {
        print('✅ [Text generation complete]');
        stopGeneration();
      },
    );

    // 6. Call the plugin's correct multimodal sending method
    // Note: We pass formattedPrompt to the underlying layer
    _llamaParent!.sendPrompt(
        formattedPrompt,
        scope: _currentScope
    );

  }

  /// Multimodal generation (text + image) - Core Edge AI feature
  Future<void> generateWithImage({
    required String prompt,
    required File imageFile,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!_isInitialized || _llamaParent == null) {
      _errorController.add('Model not initialized');
      return;
    }

    try {
      print('🖼️ [MedGemma Edge] Multimodal inference started');
      print('   - Prompt: $prompt');
      print('   - Image: ${imageFile.path} (${await imageFile.length()} bytes)');

      // Record image preprocessing time
      final preprocessStart = stopwatch.elapsedMilliseconds;
      final resizedImage = await preprocessMedicalImage(imageFile);
      // 5. Construct image object (use fromFile to avoid full memory copy between Isolates)
      final llamaImage = LlamaImage.fromFile(resizedImage);
      print('   ⏱️ Image preprocessing time: ${stopwatch.elapsedMilliseconds - preprocessStart}ms');


      // 3. Build multimodal text input
      // Must include the <image> placeholder so the model knows where to insert visual features
      final String userContent = "<image>\n$prompt";

      // 4. [Core Improvement]: Use GemmaFormat object to generate standard Prompt
      // It will be automatically wrapped as: <start_of_turn>user\n<image>\n$prompt<end_of_turn>\n<start_of_turn>model\n
      final formatStart = stopwatch.elapsedMilliseconds;
      final String formattedPrompt = _gemmaFormatter.formatPrompt(userContent);
      print('   📝 Formatted Prompt: $formattedPrompt');
      print('   ⏱️ Prompt formatting time: ${stopwatch.elapsedMilliseconds - formatStart}ms');

      _currentScope!.stream.listen(
            (response) {
              print('   📥 Received token (elapsed time ${stopwatch.elapsedMilliseconds}ms)');
          _responseController.add(response);
        },
        onError: (error) {
          print('❌ Error (${stopwatch.elapsedMilliseconds}ms): $error');
          _errorController.add('Multimodal generation error: $error');
          _currentScope = null;
        },
        onDone: () {
          print('✅ Complete (total time: ${stopwatch.elapsedMilliseconds}ms)');
          stopGeneration();
        },
      );

      // Record time before sending
      final sendStart = stopwatch.elapsedMilliseconds;
      print('   📤 Sending to the underlying model...');
      // 6. Call the plugin's correct multimodal sending method
      // Note: We pass formattedPrompt to the underlying layer
      await _llamaParent!.sendPromptWithImages(
        formattedPrompt,
        [llamaImage],
        scope: _currentScope,
      );
      print('   ✅ Sending complete (elapsed time: ${stopwatch.elapsedMilliseconds - sendStart}ms)');

    } catch (e) {
      print('❌ [Multimodal Error] $e');
      _errorController.add('Image processing failed: $e');
    }
  }

  Future<File> preprocessMedicalImage(File originalFile) async {
    // 1. Read the original image
    final bytes = await originalFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return originalFile;

    // 2. Resize to the model's preferred 224x224 
    // For medical images, linear interpolation is recommended to keep edges smooth
    final resized = img.copyResize(
        image,
        width: 112,
        height: 112,
        interpolation: img.Interpolation.linear
    );

    // 3. Save back to a cache directory
    final tempDir = originalFile.parent.path;
    final fileName = "preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final preprocessedFile = File('$tempDir/$fileName');

    // Save as high-quality JPEG to reduce file size
    await preprocessedFile.writeAsBytes(img.encodeJpg(resized, quality: 90));

    print("✅ Image preprocessing complete: from ${bytes.length} bytes reduced to ${preprocessedFile.lengthSync()} bytes");
    return preprocessedFile;
  }

  /// ✅ [Core] Stop Generation
  Future<void> stopGeneration() async {
    if (_currentScope != null) {
      // 1. Notify the underlying scope to stop (sets an internal cancel flag)
      await _currentScope!.stop(alsoCancelQueued: true);

      // 2. Key: Clear the local queue to prevent the next one from starting automatically after stopping
      await _llamaParent?.stop();

      // 3. Set the current scope to null to ensure subsequent stream listeners recognize it as invalid
      _currentScope = null;
      _currentScope=_llamaParent?.getScope();

      // 4. Update status
      print('⏹️ [Generation command issued, forcing loop termination]');
    } else {
      // Extra safety measure: directly use llamaParent's method (if supported by the plugin)
      // _llamaParent?.cancelAll();
      print('⚠️ [No active scope detected]');
    }
  }

  /// Unload model (release memory)
  Future<void> unloadModel() async {
    if (_llamaParent != null) {
      await _llamaParent!.dispose();
      _llamaParent = null;
      _isInitialized = false;
      print('✅ [MedGemma Edge] Model unloaded');
    }
  }

  /// Release resources
  void dispose() {
    unloadModel();
    _responseController.close();
    _loadingController.close();
    _errorController.close();
  }
}
