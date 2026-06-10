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
  }) async {
    try {
      await _firestore.collection('matches').doc(docId).update({
        'home_score': homeScore,
        'away_score': awayScore,
      });
      final index = matches.indexWhere((m) => m.id == docId);
      if (index != -1) {
        matches[index] = matches[index].copyWith(
          homeScore: homeScore,
          awayScore: awayScore,
        );
      }
    } catch (error) {
      Get.snackbar('خطأ', 'فشل حفظ النتيجة: $error');
    }
  }

  /// Recalculates every user's total points from scratch across ALL matches
  /// that have results. Only writes the top-level `points` field — no nested map.
  Future<void> calculateMatchPoints(MatchModel match) async {
    calculatingMatchId.value = match.id;
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      // Build a quick lookup: matchId → MatchModel (only matches with results)
      final matchesWithResults = {
        for (final m in matches)
          if (m.homeScore.isNotEmpty && m.awayScore.isNotEmpty) m.id: m,
      };

      var updatedCount = 0;
      var missingPredCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        final predictionsMap = data['predictions'] as Map<String, dynamic>?;

        if (predictionsMap == null || predictionsMap.isEmpty) {
          missingPredCount++;
          continue;
        }

        var totalPoints = 0;
        var hasPrediction = false;

        for (final entry in predictionsMap.entries) {
          final m = matchesWithResults[entry.key];
          if (m == null) continue;

          final pred = entry.value as Map<String, dynamic>?;
          if (pred == null) continue;

          hasPrediction = true;
          final breakdown = _calcBreakdown(pred, m);
          totalPoints += (breakdown['total'] as int? ?? 0);
        }

        if (!hasPrediction) {
          missingPredCount++;
          continue;
        }

        batch.update(userDoc.reference, {'points': totalPoints});
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
      };
    }

    int points;
    String rule;

    if (actualHome == predHome && actualAway == predAway) {
      points = 5;
      rule = 'نتيجة صحيحة تماماً';
    } else {
      final actualDiff = actualHome - actualAway;
      final predDiff = predHome - predAway;

      if (actualDiff == predDiff) {
        points = 3;
        rule = 'الفارق صحيح';
      } else {
        final actualWinner =
            actualHome > actualAway ? 1 : actualAway > actualHome ? -1 : 0;
        final predWinner =
            predHome > predAway ? 1 : predAway > predHome ? -1 : 0;

        if (actualWinner == predWinner) {
          points = 2;
          rule = 'الفائز صحيح';
        } else if (actualHome == predHome || actualAway == predAway) {
          points = 1;
          rule = 'أهداف فريق واحد صحيحة';
        } else {
          points = 0;
          rule = 'كل شيء خطأ';
        }
      }
    }

    return {
      'total': points,
      'predicted': predictedStr,
      'actual': actualStr,
      'rule': rule,
    };
  }
}
