import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> testWriteToFirestore() async {
  final firestore = FirebaseFirestore.instance;

  await firestore.collection('test_connection').doc('flutter_demo').set({
    'message': 'Hello from Flutter',
    'testedAt': FieldValue.serverTimestamp(),
  });
}
