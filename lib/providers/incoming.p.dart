import 'dart:developer' show log;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sip_ua/sip_ua.dart' show Call;

part 'incoming.p.g.dart';

@riverpod
class IncomingCalls extends _$IncomingCalls {
  @override
  Call? build() => null;

  void set(Call? c) => state = c;
}

Call? tempCall;
Future<void> answer() async {
  if (tempCall == null) {
    return;
  }

  try {
    final answerOptions = {
      'mediaConstraints': {'audio': true, 'video': false},
    };
    tempCall!.answer(answerOptions);
  } catch (e) {
    log('Answer Call Error: ------- ${e.toString()}');
  }
}
