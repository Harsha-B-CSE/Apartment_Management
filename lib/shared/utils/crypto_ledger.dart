import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class CryptoLedger {
  /// Asynchronously generates a SHA-256 hash in a background isolate.
  /// It takes the stringified data of the transaction to generate an immutable hash.
  static Future<String> generateTransactionHash(Map<String, dynamic> data) async {
    return await compute(_hashData, data);
  }

  /// The isolate function that performs the heavy cryptographic math.
  static String _hashData(Map<String, dynamic> data) {
    // 1. Sort the keys to ensure consistent hashing
    final sortedKeys = data.keys.toList()..sort();
    
    // 2. Build a deterministic string representation of the data
    String rawString = '';
    for (var key in sortedKeys) {
      if (key == 'hash') continue; // exclude existing hash from calculation
      rawString += '$key:${data[key].toString()}|';
    }

    // 3. Apply SHA-256
    final bytes = utf8.encode(rawString);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }
}
