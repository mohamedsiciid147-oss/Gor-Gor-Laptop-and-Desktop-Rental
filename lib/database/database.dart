import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

class Db {
  static const String baseUrl =
      'https://qedzqesmqigyuxpzicnl.supabase.co/rest/v1/';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlZHpxZXNtcWlneXV4cHppY25sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzNTEzMTEsImV4cCI6MjA5NjkyNzMxMX0.HHeTDgWGUG0YMIymanN_jVaujGX11TS35jKD1sdaFaU'; // Your actual Anon Key

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
  };

  // GET: Now accepts a Map for filters and converts it to a String
  static Future<dynamic> get(
    String table, {
    dynamic id, // Added this to fix your error
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    String? order,
  }) async {
    // Start with the base table URL
    String url = '$baseUrl/$table?select=*';

    // 1. If an ID is passed, add it as a filter
    if (id != null) {
      url += '&id=eq.$id';
    }

    // 2. If a filters map is passed, add those too
    if (filters != null) {
      filters.forEach((key, value) {
        url += '&$key=eq.$value';
      });
    }

    if (limit != null) url += '&limit=$limit';
    if (offset != null) url += '&offset=$offset';
    if (order != null && order.isNotEmpty) url += '&order=$order';

    final response = await http.get(Uri.parse(url), headers: _headers);

    // Supabase returns a List by default.
    // If we searched by ID, we usually just want the first (and only) item.
    final List<dynamic> data = jsonDecode(response.body);

    if (id != null && data.isNotEmpty) {
      return data.first; // Return as Map<String, dynamic>
    }

    return data; // Return as List<dynamic>
  }

  // ================== POST (Create) ==================
  static Future<dynamic> post(String table, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$table'),
      headers: {
        ..._headers,
        'Prefer': 'return=representation', // Returns the inserted row
      },
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // UPDATE: Accepts dynamic ID and handles the filter string internally
  static Future<dynamic> update(
    String table,
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/$table?id=eq.$id'), // Filter built here
      headers: {..._headers, 'Prefer': 'return=representation'},
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  // ================== DELETE ==================
  static Future<dynamic> delete(String table, {dynamic id, String? filter}) async {
    String query;
    if (filter != null && filter.isNotEmpty) {
      query = filter;
    } else if (id != null) {
      query = 'id=eq.$id';
    } else {
      throw Exception('Delete requires either id or filter.');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/$table?$query'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  // ================== HELPER ==================
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<String> uploadImage({
    required String bucket,
    required String fileName,
    String? filePath, // Used for mobile/desktop
    Uint8List? fileBytes, // Used for web compatibility
  }) async {
    final uri = Uri.parse(
      'https://qedzqesmqigyuxpzicnl.supabase.co/storage/v1/object/$bucket/$fileName',
    );

    final request = http.MultipartRequest('POST', uri);

    // Add Auth Headers
    request.headers.addAll({
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
    });

    // Attach the file properly depending on platform data type
    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType(
            'image',
            'png',
          ), // Explicitly pass image header
        ),
      );
    } else if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType('image', 'png'),
        ),
      );
    } else {
      throw Exception('No valid file source data found to upload.');
    }

    final response = await request.send();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return fileName;
    }

    // Read response error message from Supabase to log exactly why it threw 400
    final responseBody = await response.stream.bytesToString();
    throw Exception('Upload failed (${response.statusCode}): $responseBody');
  }

  static String getImageUrl({
    required String bucket,
    required String fileName,
  }) {
    return 'https://qedzqesmqigyuxpzicnl.supabase.co/storage/v1/object/public/$bucket/$fileName';
  }

  static Future<void> deleteImage({
    required String bucket,
    required String fileName,
  }) async {
    final response = await http.delete(
      Uri.parse(
        'https://qedzqesmqigyuxpzicnl.supabase.co/storage/v1/object/$bucket/$fileName',
      ),
      headers: {'apikey': anonKey, 'Authorization': 'Bearer $anonKey'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Delete failed: ${response.body}');
    }
  }
}
