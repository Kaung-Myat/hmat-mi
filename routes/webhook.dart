import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:teledart/model.dart' hide Response;

import '../main.dart';

Future<Response> onRequest(RequestContext context) async {
  // POST Request မဟုတ်ရင် လက်မခံဘူး
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.body();
    final json = jsonDecode(body) as Map<String, dynamic>;

    // Update Object အဖြစ်ပြောင်းမယ်
    final update = Update.fromJson(json);

    webhookFetcher.addUpdate(update);

    return Response(body: 'OK');
  } catch (e) {
    print('Webhook Error: $e');
    return Response(statusCode: HttpStatus.badRequest);
  }
}
