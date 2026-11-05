/// 离线语音模型清单（与原生 SttModelCatalog / TtsModelCatalog 一致）
class ModelFile {
  const ModelFile(this.name, this.sizeBytes);

  final String name;
  final int sizeBytes;
}

class VoiceModel {
  const VoiceModel({
    required this.id,
    required this.displayName,
    required this.repo,
    required this.files,
    required this.languages,
  });

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

  static const all = [melo];

  static VoiceModel byId(String? id) =>
      all.firstWhere((m) => m.id == id, orElse: () => melo);
}
