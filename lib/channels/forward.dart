import 'package:flutter/services.dart';

class TelegramForwarder {
  static const MethodChannel _channel = const MethodChannel(
    'telegram_forwarder',
  );

  static Future<bool> forwardToTelegram({
    required String filePath,
    required String botToken,
    required String chatId,
  }) async {
    try {
      return await _channel.invokeMethod('forwardToTelegram', {
        'filePath': filePath,
        'botToken': botToken,
        'chatId': chatId,
      });
    } on PlatformException catch (e) {
      print("Failed to forward file: ${e.message}");
      return false;
    }
  }
}


// TelegramForwarder.forwardToTelegram(
//   filePath: '/storage/emulated/0/DCIM/Camera/image.jpg',
//   botToken: '123456789:AAEe0XMPIe0XMPIe0XMPIe0XMPIe0XMP',
//   chatId: '@my_kids_monitor_channel',
// );