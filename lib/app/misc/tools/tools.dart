import 'package:shakepin/app/misc/tools/convert_to_ico/convert_to_ico_tool.dart';
import 'package:shakepin/app/misc/tools/convert_to_wav/convert_to_wav_tool.dart';
import 'package:shakepin/app/misc/tools/tool.dart';

enum ToolType {
  convertToIco,
  convertToWav,
}

class Tools {
  static String getToolName(ToolType type) {
    switch (type) {
      case ToolType.convertToIco:
        return 'Convert to ICO';
      case ToolType.convertToWav:
        return 'Convert to 16kHz WAV';
    }
  }

  static ToolWidget getToolWidget(ToolType type) {
    switch (type) {
      case ToolType.convertToIco:
        return const ConvertToIcoTool();
      case ToolType.convertToWav:
        return const ConvertToWavTool();
    }
  }
}
