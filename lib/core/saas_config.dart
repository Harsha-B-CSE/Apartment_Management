// lib/core/saas_config.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SaasConfig {
  // 🎨 Branding Settings (Instance Fields)
  String appName;
  String tagline;
  bool allowSelfSignup;
  String primaryColorHex;

  // 💰 Financial Tier Variables (Made static to satisfy background daemons)
  static String currencySymbol = '₹';
  static double maintenance2BHK = 5000.0;
  static double maintenanceAbove2BHK = 8000.0;

  SaasConfig({
    required this.appName,
    required this.tagline,
    required this.allowSelfSignup,
    required this.primaryColorHex,
    required String currency,
    required double m2bhk,
    required double mAbove2bhk,
  }) {
    // Assigning incoming values straight to our static fields safely upon initialization
    currencySymbol = currency;
    maintenance2BHK = m2bhk;
    maintenanceAbove2BHK = mAbove2bhk;
  }

  static SaasConfig? _instance;
  static SaasConfig get instance => _instance ?? _default;

  // ─── 🚀 THE INSTANCE PROXIES ───
  // By changing these to slightly unique names on the instance side, we avoid the name clash!
  // Simply update your UI screens to use these extensions, or read below to see how to fix the screens.
  String get currency => currencySymbol;
  double get m2BHK => maintenance2BHK;
  double get mAbove2BHK => maintenanceAbove2BHK;

  // 🛡️ Safe Default Global Parameters
  static final _default = SaasConfig(
    appName: 'Apartment Pro',
    tagline: 'Living Simplified',
    allowSelfSignup: true,
    primaryColorHex: '#1A2B4A',
    currency: '₹',
    m2bhk: 5000.0,
    mAbove2bhk: 8000.0,
  );

  static Future<void> init() async {
    // 1. Load from local Assets (Safe Fallback)
    try {
      final String response = await rootBundle.loadString('assets/config/saas_config.json');
      final data = json.decode(response);
      _instance = SaasConfig(
        appName: data['appName'] ?? _default.appName,
        tagline: data['tagline'] ?? _default.tagline,
        allowSelfSignup: data['allowSelfSignup'] ?? _default.allowSelfSignup,
        primaryColorHex: data['primaryColorHex'] ?? _default.primaryColorHex,
        currency: data['currencySymbol'] ?? _default.currency,
        m2bhk: (data['maintenance2BHK'] as num?)?.toDouble() ?? _default.m2BHK,
        mAbove2bhk: (data['maintenanceAbove2BHK'] as num?)?.toDouble() ?? _default.mAbove2BHK,
      );
    } catch (e) {
      _instance = _default;
    }

    // 2. Try to override from Firestore (Real-time update)
    try {
      final doc = await FirebaseFirestore.instance.collection('saas_config').doc('main').get();
      if (doc.exists) {
        final data = doc.data()!;
        _instance = SaasConfig(
          appName: data['appName'] ?? _instance!.appName,
          tagline: data['tagline'] ?? _instance!.tagline,
          allowSelfSignup: data['allowSelfSignup'] ?? _instance!.allowSelfSignup,
          primaryColorHex: data['primaryColorHex'] ?? _instance!.primaryColorHex,
          currency: data['currencySymbol'] ?? currencySymbol,
          m2bhk: (data['maintenance2BHK'] as num?)?.toDouble() ?? maintenance2BHK,
          mAbove2bhk: (data['maintenanceAbove2BHK'] as num?)?.toDouble() ?? maintenanceAbove2BHK,
        );
      }
    } catch (_) {}
  }
}