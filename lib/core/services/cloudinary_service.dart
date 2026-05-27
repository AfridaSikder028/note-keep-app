import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  late final String cloudName;
  late final String uploadPreset;

  Future<void> init() async {
    cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
    print('🔵 Cloud Name: $cloudName, Preset: $uploadPreset');
  }

  Future<html.File?> pickImage() async {
    print('🔵 pickImage() called');
    final completer = Completer<html.File?>();
    final input = html.FileUploadInputElement();
    input.accept = 'image/jpeg, image/png, image/jpg';
    input.multiple = false;
    input.click();
    
    input.onChange.listen((_) {
      if (input.files!.isEmpty) {
        print('⚠️ No file selected');
        completer.complete(null);
      } else {
        final file = input.files![0];
        print('🔵 File selected: ${file.name}, size: ${file.size} bytes');
        completer.complete(file);
      }
    });
    
    return completer.future;
  }

  Future<String> uploadImage(html.File imageFile) async {
    print('🔵 uploadImage() called for: ${imageFile.name}');
    
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      
      // File থেকে bytes পড়ার সঠিক পদ্ধতি
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      
      reader.readAsArrayBuffer(imageFile);
      reader.onLoadEnd.listen((_) {
        completer.complete(reader.result as Uint8List);
      });
      
      final bytes = await completer.future;
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
      ));
      
      print('🔵 Sending to Cloudinary...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('🔵 Response status: ${response.statusCode}');
      
      final jsonResponse = json.decode(responseBody);
      
      if (response.statusCode == 200) {
        final imageUrl = jsonResponse['secure_url'] as String;
        print('✅✅✅ SUCCESS! URL: $imageUrl');
        return imageUrl;
      } else {
        throw Exception(jsonResponse['error']['message']);
      }
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }
}