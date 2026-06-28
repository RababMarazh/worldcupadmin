import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/match_model.dart';

class MatchController extends GetxController {
  final matches = <MatchModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final calculatingMatchId = ''.obs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<MatchModel> get sortedMatches {
    final sorted = matches.toList();
    sorted.sort((a, b) {
      final aDate = a.dateTime;
      final bDate = b.dateTime;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return sorted;
  }

  List<MatchModel> get todayMatches {
    final today = matches.where((match) => match.isToday).toList();
    if (today.isNotEmpty) return today;
    return upcomingMatches;
  }

  List<MatchModel> get upcomingMatches => sortedMatches;

  @override
  void onInit() {
    super.onInit();
    loadMatches();
  }

  Future<void> loadMatches() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final snapshot = await _firestore.collection('matches').get();
      if (snapshot.docs.isEmpty) {
        errorMessage.value =
            'No matches found in Firestore. Please import match data into the "matches" collection.';
        return;
      }
      matches.value = snapshot.docs
          .map((doc) => MatchModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (error) {
      errorMessage.value = 'Could not load matches from Firestore: $error';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateMatchResult({
    required String docId,
    required String homeScore,
    required String awayScore,
    String homeScorers = '',
    String awayScorers = '',
  }) async {
    try {
      await _firestore.collection('matches').doc(docId).update({
        'home_score': homeScore,
        'away_score': awayScore,
        'home_scorers': homeScorers,
        'away_scorers': awayScorers,
      });
      final index = matches.indexWhere((m) => m.id == docId);
      if (index != -1) {
        matches[index] = matches[index].copyWith(
          homeScore: homeScore,
          awayScore: awayScore,
          homeScorers: homeScorers,
          awayScorers: awayScorers,
        );
      }
    } catch (error) {
      Get.snackbar('خطأ', 'فشل حفظ النتيجة: $error');
    }
  }

  Future<void> updateMatchTeams({
    required String docId,
    required String homeTeam,
    required String awayTeam,
  }) async {
    try {
      await _firestore.collection('matches').doc(docId).update({
        'home_team_name_en': homeTeam,
        'away_team_name_en': awayTeam,
      });
      final index = matches.indexWhere((m) => m.id == docId);
      if (index != -1) {
        matches[index] = matches[index].copyWith(
          homeTeam: homeTeam,
          awayTeam: awayTeam,
        );
      }
      Get.snackbar('تم', 'تم حفظ أسماء الفرق');
    } catch (error) {
      Get.snackbar('خطأ', 'فشل حفظ أسماء الفرق: $error');
    }
  }

  /// Recalculates every user's total points from scratch across ALL completed
  /// matches. Triggered when any single match result is saved.
  Future<void> calculateMatchPoints(MatchModel match) async {
    calculatingMatchId.value = match.id;
    try {
      // All matches that have a valid numeric result.
      final completedMatches = matches.where((m) {
        return int.tryParse(m.homeScore) != null &&
            int.tryParse(m.awayScore) != null;
      }).toList();

      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      var updatedCount = 0;
      var missingPredCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        final predictionsMap = data['predictions'] as Map<String, dynamic>?;

        if (predictionsMap == null || predictionsMap.isEmpty) {
          missingPredCount++;
          continue;
        }

        // Recalculate points for every completed match from scratch.
        final allMatchPoints = <String, dynamic>{};
        var totalPoints = 0;
        var hasPrediction = false;

        for (final m in completedMatches) {
          final pred = predictionsMap[m.id] as Map<String, dynamic>?;
          if (pred == null) continue;

          hasPrediction = true;
          final breakdown = _calcBreakdown(pred, m);
          final pts = breakdown['total'] as int? ?? 0;
          totalPoints += pts;

          allMatchPoints[m.id] = {
            'points': pts,
            'predicted': breakdown['predicted'],
            'actual': breakdown['actual'],
            'outcome': breakdown['outcome'],
            'oneGoalCorrect': pts == 1,
          };
        }

        if (!hasPrediction) {
          missingPredCount++;
          continue;
        }

        batch.update(userDoc.reference, {
          'points': totalPoints,
          'match_points': allMatchPoints,
        });
        updatedCount++;
      }

      await batch.commit();

      if (updatedCount == 0) {
        Get.snackbar(
          'تنبيه',
          'لا توجد توقعات مسجّلة بعد',
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'تم',
          'تم تحديث نقاط $updatedCount مستخدم'
              '${missingPredCount > 0 ? ' • $missingPredCount بدون توقع' : ''}',
        );
      }
    } catch (error) {
      Get.snackbar('خطأ', 'فشل احتساب النقاط: $error');
    } finally {
      calculatingMatchId.value = '';
    }
  }

  // ── points engine ─────────────────────────────────────────────────────────
  //
  // Rules:
  //   +5  exact score correct
  //   +3  correct goal difference (implies correct winner)
  //   +2  correct winner but wrong difference
  //   +1  wrong winner but one team's goal count is correct
  //    0  everything wrong

  static Map<String, dynamic> _calcBreakdown(
    Map<String, dynamic> pred,
    MatchModel match,
  ) {
    final actualHome = int.tryParse(match.homeScore);
    final actualAway = int.tryParse(match.awayScore);
    final predHome = int.tryParse(pred['home_score']?.toString() ?? '');
    final predAway = int.tryParse(pred['away_score']?.toString() ?? '');

    final predictedStr = (predHome != null && predAway != null)
        ? '$predHome - $predAway'
        : '—';
    final actualStr = (actualHome != null && actualAway != null)
        ? '$actualHome - $actualAway'
        : '—';

    if (actualHome == null ||
        actualAway == null ||
        predHome == null ||
        predAway == null) {
      return {
        'total': 0,
        'predicted': predictedStr,
        'actual': actualStr,
        'rule': 'لا نتيجة',
        'outcome': 'wrong',
      };
    }

    int points;
    String rule;

    String outcome;

    if (actualHome == predHome && actualAway == predAway) {
      points = 5;
      rule = 'نتيجة صحيحة تماماً';
      outcome = 'exact';
    } else {
      final actualDiff = actualHome - actualAway;
      final predDiff = predHome - predAway;

      if (actualDiff == predDiff) {
        points = 3;
        rule = 'الفارق صحيح';
        outcome = 'correctDiff';
      } else {
        final actualWinner = actualHome > actualAway
            ? 1
            : actualAway > actualHome
            ? -1
            : 0;
        final predWinner = predHome > predAway
            ? 1
            : predAway > predHome
            ? -1
            : 0;

        if (actualWinner == predWinner) {
          points = 2;
          rule = 'الفائز صحيح';
          outcome = 'correctWinner';
        } else if (actualHome == predHome || actualAway == predAway) {
          points = 1;
          rule = 'أهداف فريق واحد صحيحة';
          outcome = 'oneGoalCorrect';
        } else {
          points = 0;
          rule = 'كل شيء خطأ';
          outcome = 'wrong';
        }
      }
    }

    return {
      'total': points,
      'predicted': predictedStr,
      'actual': actualStr,
      'rule': rule,
      'outcome': outcome,
    };
  }

  // ── collection duplicator ─────────────────────────────────────────────────

  /// Copies [matches] → [matches_<suffix>] and [users] → [users_<suffix>].
  /// Uses chunked batches to stay under Firestore's 500-op limit.
  Future<void> duplicateCollections(String suffix) async {
    final tag = suffix.trim();
    if (tag.isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال اسم للنسخة');
      return;
    }

    Get.snackbar(
      'جارٍ النسخ…',
      'يرجى الانتظار',
      duration: const Duration(seconds: 60),
    );

    try {
      final matchSnap = await _firestore.collection('matches').get();
      final userSnap = await _firestore.collection('users').get();
      final tableSnap = await _firestore.collection('tables').get();

      await _copyDocs(matchSnap.docs, 'matches_$tag');
      await _copyDocs(userSnap.docs, 'users_$tag');
      await _copyDocs(tableSnap.docs, 'tables_$tag');

      Get.closeAllSnackbars();
      Get.snackbar(
        'تم',
        'تم نسخ ${matchSnap.docs.length} مباراة و ${userSnap.docs.length} مستخدم'
            ' إلى matches_$tag و users_$tag',
        duration: const Duration(seconds: 6),
      );
    } catch (e) {
      Get.closeAllSnackbars();
      Get.snackbar('خطأ', 'فشل النسخ: $e');
    }
  }

  Future<void> _copyDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String targetCollection,
  ) async {
    const chunkSize = 400;
    for (var i = 0; i < docs.length; i += chunkSize) {
      final chunk = docs.sublist(i, min(i + chunkSize, docs.length));
      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.set(
          _firestore.collection(targetCollection).doc(doc.id),
          doc.data(),
        );
      }
      await batch.commit();
    }
  }
}
