import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/match_model.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _loading = true;
  String? _error;
  List<_MatchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matchSnap = await FirebaseFirestore.instance
          .collection('matches')
          .get();
      final completedMatches =
          matchSnap.docs
              .map((d) => MatchModel.fromJson({'id': d.id, ...d.data()}))
              .where(
                (m) =>
                    int.tryParse(m.homeScore) != null &&
                    int.tryParse(m.awayScore) != null,
              )
              .toList()
            ..sort((a, b) {
              final ad = a.dateTime;
              final bd = b.dateTime;
              if (ad == null && bd == null) return 0;
              if (ad == null) return 1;
              if (bd == null) return -1;
              return ad.compareTo(bd);
            });

      if (completedMatches.isEmpty) {
        setState(() {
          _results = [];
          _loading = false;
        });
        return;
      }

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // Build a map: matchId → list of user names who got it exactly right
      final exactMap = <String, List<String>>{
        for (final m in completedMatches) m.id: [],
      };
      // And a map for correct winner (exact + correctDiff + correctWinner)
      final winnerMap = <String, List<String>>{
        for (final m in completedMatches) m.id: [],
      };

      for (final userDoc in userSnap.docs) {
        final data = userDoc.data();
        final name = data['name'] as String? ?? '—';
        final mp = data['match_points'] as Map<String, dynamic>?;
        if (mp == null) continue;

        for (final m in completedMatches) {
          final entry = mp[m.id] as Map<String, dynamic>?;
          if (entry == null) continue;
          final outcome = entry['outcome'] as String? ?? 'wrong';

          if (outcome == 'exact') {
            exactMap[m.id]!.add(name);
            winnerMap[m.id]!.add(name);
          } else if (outcome == 'correctDiff' || outcome == 'correctWinner') {
            winnerMap[m.id]!.add(name);
          }
        }
      }

      setState(() {
        _results = completedMatches.map((m) {
          final exact = List<String>.from(exactMap[m.id]!)..sort();
          final winner = List<String>.from(winnerMap[m.id]!)..sort();
          return _MatchResult(match: m, exactNames: exact, winnerNames: winner);
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        title: const Text(
          'من أصاب النتيجة؟',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            )
          : _results.isEmpty
          ? const Center(
              child: Text(
                'لا توجد مباريات منتهية بعد',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, i) =>
                  _MatchResultCard(result: _results[i]),
            ),
    );
  }
}

// ── data ──────────────────────────────────────────────────────────────────────

class _MatchResult {
  const _MatchResult({
    required this.match,
    required this.exactNames,
    required this.winnerNames,
  });

  final MatchModel match;

  /// Users who predicted the exact score (5 pts).
  final List<String> exactNames;

  /// Users who predicted the correct winner/draw (2–5 pts), includes exact.
  final List<String> winnerNames;
}

// ── card ──────────────────────────────────────────────────────────────────────

class _MatchResultCard extends StatelessWidget {
  const _MatchResultCard({required this.result});
  final _MatchResult result;

  @override
  Widget build(BuildContext context) {
    final m = result.match;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2F4E), Color(0xFF132238)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── match header ──────────────────────────────────────────────
            Row(
              children: [
                _TeamBlock(name: m.homeTeam, logoUrl: m.fixedHomeLogoUrl),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${m.homeScore}  -  ${m.awayScore}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      if (m.group.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          m.group,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _TeamBlock(
                  name: m.awayTeam,
                  logoUrl: m.fixedAwayLogoUrl,
                  rightAlign: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),

            // ── exact score section ───────────────────────────────────────
            _NamesSection(
              icon: '🎯',
              label: 'المتوقعين الصح',
              names: result.exactNames,
              color: const Color(0xFF00C853),
              emptyLabel: 'لا أحد',
            ),

            const SizedBox(height: 14),

            // ── correct winner section ────────────────────────────────────
            // _NamesSection(
            //   icon: '✅',
            //   label: 'أصابوا الفائز',
            //   names: result.winnerNames,
            //   color: const Color(0xFF448AFF),
            //   emptyLabel: 'لا أحد',
            // ),
          ],
        ),
      ),
    );
  }
}

// ── team block ────────────────────────────────────────────────────────────────

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.name,
    required this.logoUrl,
    this.rightAlign = false,
  });

  final String name;
  final String logoUrl;
  final bool rightAlign;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          logoUrl.isEmpty
              ? const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white12,
                  child: Icon(Icons.flag, color: Colors.white38),
                )
              : CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white12,
                  backgroundImage: NetworkImage(logoUrl),
                  onBackgroundImageError: (_, _) {},
                ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── names section ─────────────────────────────────────────────────────────────

class _NamesSection extends StatelessWidget {
  const _NamesSection({
    required this.icon,
    required this.label,
    required this.names,
    required this.color,
    required this.emptyLabel,
  });

  final String icon;
  final String label;
  final List<String> names;
  final Color color;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // section title
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${names.length}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // names
        if (names.isEmpty)
          Text(
            emptyLabel,
            style: const TextStyle(color: Colors.white24, fontSize: 13),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: names
                .map(
                  (n) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      n,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
