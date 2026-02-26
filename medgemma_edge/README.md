# 🚀 MedGemma-Edge: On-Device Clinical Assistant

**MedGemma-Edge** is a privacy-focused, 100% offline medical AI assistant. By leveraging the **MedGemma 4B** model and `llama_cpp_dart`, we bring high-fidelity clinical reasoning to mobile hardware—even on 5-year-old budget devices like the **Dimensity 700**.

---

## 🛠 Core Architecture: `llama_service.dart`

The backbone of the application is a high-performance multimodal service layer built on top of `llama.cpp`.

### Key Features:

- **Singleton Pattern**: Ensures a globally unique model instance to optimize RAM usage.

- **Multimodal Integration**: Simultaneous processing of medical text prompts and high-resolution X-ray/clinical images.

- **Streaming Inference**: Real-time response generation for a better user experience on constrained hardware.

- **Hardware-Aware Optimization**: Configured to run on 4-bit quantized weights to fit within mobile VRAM limits.

- **Session Management**: Persistent state handling with robust error-recovery mechanisms.


---

## 📥 Getting Started: Model Preparation

To run this application, you need to download the quantized GGUF weights. We recommend the **Q4_K_M** quantization for the best balance between speed and diagnostic accuracy.

1. **Language Model (LLM):** [medgemma-4b-it-Q4_K_M.gguf](https://huggingface.co/second-state/medgemma-4b-it-GGUF/tree/main)

2. **Vision Projector (MMProj):** [mmproj-medgemma-4b-it-Q8_0.gguf](https://huggingface.co/kelkalot/medgemma-4b-it-GGUF/tree/main)


---

## 🏗 Build & Installation (Android)

### 1. Compilation

Ensure you have the Flutter SDK installed. Run the following in your terminal:

Bash

```
flutter clean
flutter pub get

# Build optimized APK for specific architectures (ARM64-v8a recommended)
flutter build apk --split-per-abi --release
```

### 2. Transfer to Device

You can transfer the generated APK (found in `build/app/outputs/flutter-apk/`) via:

- **USB Cable**: Standard file transfer.

- **LocalSend**: An excellent open-source tool for high-speed Wi-Fi transfers. [Download LocalSend here](https://localsend.org/download).


### 3. Deploy Model Files

Due to the large size of LLM weights, they must be manually placed in the app's external storage directory:

1. Install and **launch the app once** to create the necessary system folders.

2. Locate the app data directory (usually): `Internal Storage/Android/data/com.example.medgemma_edge/files/`

3. Copy the `.gguf` and `mmproj` files into this directory.

4. **Restart the App.**


---

## 📉 Performance Baseline (Low-End Hardware)

- **Test Device:** Dimensity 700 (Released 2020)

- **RAM:** 6GB

- **Optimization:** 4-bit Quantization + 2-Thread Execution.

- **Privacy:** 100% Offline (No data leaves the device).


---

## 🔮 Future Roadmap: Hardware-Aware Adaptation

We are developing a **Hardware-Aware Adaptation Layer** to dynamically profile device RAM and SoC. This will allow the engine to automatically toggle between high-fidelity (flagship) and energy-saving (entry-level) inference modes, ensuring a consistent experience across the fragmented Android ecosystem.








