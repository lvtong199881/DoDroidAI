/// 离线语音模型清单（与原生 SttModelCatalog / TtsModelCatalog 一致）
class ModelFile {
  const ModelFile(this.name, this.sizeBytes, {this.repo, this.url});

  final String name;
  final int sizeBytes;

  /// 覆盖 VoiceModel.repo：同一模型可能有文件来自其它仓库（如 vocoder）
  final String? repo;

  /// 完整下载地址，覆盖按下载源拼接的默认 URL
  final String? url;
}

class VoiceModel {
  const VoiceModel({
    required this.id,
    required this.displayName,
    required this.repo,
    required this.files,
    required this.languages,
    this.kind = 'vits',
  });

  /// 'vits' 或 'matcha'
  final String kind;

  final String id;
  final String displayName;
  final String repo;
  final List<ModelFile> files;
  final String languages;

  int get totalBytes => files.fold(0, (sum, f) => sum + f.sizeBytes);

  String formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

enum ModelSource { hfMirror, huggingFace }

String downloadUrl(ModelSource source, String repo, String fileName) {
  final base = source == ModelSource.hfMirror
      ? 'https://hf-mirror.com'
      : 'https://huggingface.co';
  return '$base/$repo/resolve/main/$fileName';
}

class SttModels {
  static const senseVoice = VoiceModel(
    id: 'sense_voice_2025_09_09',
    displayName: 'SenseVoice Small',
    repo: 'csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09',
    files: [
      ModelFile('tokens.txt', 315894),
      ModelFile('model.int8.onnx', 237115547),
    ],
    languages: '中文 / 英文 / 粤语 / 日语 / 韩语',
  );

  static const all = [senseVoice];

  static VoiceModel byId(String? id) =>
      all.firstWhere((m) => m.id == id, orElse: () => senseVoice);
}

class TtsModels {
  static const melo = VoiceModel(
    id: 'vits_melo_tts_zh_en',
    displayName: 'MeloTTS 中英混合',
    repo: 'csukuangfj/vits-melo-tts-zh_en',
    files: [
      ModelFile('model.int8.onnx', 53517430),
      ModelFile('tokens.txt', 655),
      ModelFile('lexicon.txt', 6837671),
      ModelFile('date.fst', 59154),
      ModelFile('new_heteronym.fst', 21974),
      ModelFile('number.fst', 64482),
      ModelFile('phone.fst', 88630),
      ModelFile('dict/hmm_model.utf8', 519739),
      ModelFile('dict/idf.utf8', 5998717),
      ModelFile('dict/jieba.dict.utf8', 5071204),
      ModelFile('dict/pos_dict/char_state_tab.utf8', 327139),
      ModelFile('dict/pos_dict/prob_emit.utf8', 1687686),
      ModelFile('dict/pos_dict/prob_start.utf8', 4347),
      ModelFile('dict/pos_dict/prob_trans.utf8', 124159),
      ModelFile('dict/stop_words.utf8', 8974),
      ModelFile('dict/user.dict.utf8', 49),
    ],
    languages: '中文 / 英文',
  );

  /// Matcha-TTS：ODE 步数少，移动端明显快于 VITS。
  /// 必须搭配 vocos-16khz-univ.onnx（官方 README 明确要求），否则无法合成。
  static const matcha = VoiceModel(
    id: 'matcha_icefall_zh_en',
    displayName: 'Matcha 中英混合（更快）',
    repo: 'csukuangfj/matcha-icefall-zh-en',
    kind: 'matcha',
    files: [
      ModelFile('model-steps-3.onnx', 75717082),
      ModelFile('tokens.txt', 21146),
      ModelFile('lexicon.txt', 1400278),
      ModelFile('date-zh.fst', 59154),
      ModelFile('number-zh.fst', 64482),
      ModelFile('phone-zh.fst', 88630),
      ModelFile(
        'vocos-16khz-univ.onnx',
        53882848,
        repo: 'wmghf2023/vocos-16khz-univ-mirror',
      ),
    ],
    languages: '中文 / 英文',
  );

  static const all = [matcha, melo];

  static VoiceModel byId(String? id) =>
      all.firstWhere((m) => m.id == id, orElse: () => matcha);
}
