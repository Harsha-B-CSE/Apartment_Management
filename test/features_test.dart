import 'package:flutter_test/flutter_test.dart';
import 'package:apartment_app/shared/utils/crypto_ledger.dart';
import 'package:apartment_app/shared/utils/nlp_triage_engine.dart';

void main() {
  group('Smart Complaint Triage Engine Tests', () {
    test('Plumbing Emergency Routing', () async {
      final text = "There is a massive water pipe burst and it is flooding my living room!";
      final result = await NlpTriageEngine.analyzeComplaint(text);
      
      expect(result.category, 'Plumbing');
      expect(result.urgency, 'Emergency');
    });

    test('Electrical High Urgency Routing', () async {
      final text = "The light switch is broken and sparking.";
      final result = await NlpTriageEngine.analyzeComplaint(text);
      
      expect(result.category, 'Electrical');
      expect(result.urgency, 'Emergency');
    });

    test('General Disturbance Routing', () async {
      final text = "My neighbor is having a very loud party and there is a lot of noise.";
      final result = await NlpTriageEngine.analyzeComplaint(text);
      
      expect(result.category, 'Disturbance');
      expect(result.urgency, 'Medium');
    });
  });

  group('Cryptographic Ledger Tests', () {
    test('Hash Generation is Deterministic', () async {
      final data1 = {'amount': 500, 'tenant': 'Alice', 'status': 'paid'};
      final data2 = {'status': 'paid', 'tenant': 'Alice', 'amount': 500};
      
      final hash1 = await CryptoLedger.generateTransactionHash(data1);
      final hash2 = await CryptoLedger.generateTransactionHash(data2);
      
      // Despite different key orders, hash must be identical
      expect(hash1, equals(hash2));
    });

    test('Tampering Detection', () async {
      final original = {'amount': 500, 'tenant': 'Alice'};
      final tampered = {'amount': 50, 'tenant': 'Alice'};
      
      final hash1 = await CryptoLedger.generateTransactionHash(original);
      final hash2 = await CryptoLedger.generateTransactionHash(tampered);
      
      // Hash must drastically change for small modifications
      expect(hash1, isNot(equals(hash2)));
    });
  });
}
