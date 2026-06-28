import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/match_controller.dart';
import '../controllers/user_controller.dart';
import '../models/match_model.dart';
import 'expectations_page.dart';
import 'leaderboard_page.dart';
import 'stats_page.dart';
import 'users_page.dart';

void _showDuplicateDialog(BuildContext context, MatchController controller) {
  final suffixCtrl = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('نسخ البيانات'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أدخل اسمًا للنسخة. سيتم إنشاء:\n'
            '• matches_<الاسم>\n'
            '• users_<الاسم>',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: suffixCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'اسم النسخة',
              hintText: 'مثال: backup_june',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy_all, size: 18),
          label: const Text('نسخ'),
          onPressed: () {
            Navigator.pop(ctx);
            controller.duplicateCollections(suffixCtrl.text);
          },
        ),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MatchController());
    final userController = Get.put(UserController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('World Cup 2026'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'نسخ البيانات',
            onPressed: () => _showDuplicateDialog(context, Get.find<MatchController>()),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'إحصائيات التوقعات',
            onPressed: () => Get.to(() => const StatsPage()),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'الترتيب',
            onPressed: () => Get.to(() => const LeaderboardPage()),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'إدارة المستخدمين',
            onPressed: () => Get.to(() => const UsersPage()),
          ),
          Obx(() {
            final user = userController.currentUser.value;
            if (user != null && user.profilePictureUrl.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () {
                    if (userController.currentUser.value != null) {
                      Get.to(() => const ExpectationsPage());
                    } else {
                      Get.to(() => const HomePage());
                    }
                  },
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(user.profilePictureUrl),
                    onBackgroundImageError: (exception, stackTrace) {},
                    child: const Icon(Icons.person),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () {
                  if (userController.currentUser.value != null) {
                    Get.to(() => const ExpectationsPage());
                  } else {
                    Get.to(() => const HomePage());
                  }
                },
                child: const CircleAvatar(child: Icon(Icons.person)),
              ),
            );
          }),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.errorMessage.isNotEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      controller.errorMessage.value,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: controller.loadMatches,
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }

              final sortedMatches = controller.sortedMatches;
              if (sortedMatches.isEmpty) {
                return const Center(
                  child: Text(
                    'No match data available.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              final sectionItems = <dynamic>[];
              String currentDate = '';
              var matchCounter = 0;
              for (final match in sortedMatches) {
                if (match.dateHeader != currentDate) {
                  currentDate = match.dateHeader;
                  sectionItems.add(currentDate);
                }
                sectionItems.add({
                  'match': match,
                  'matchNumber': ++matchCounter,
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'FIFA World Cup 2026™ Schedule',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Browse the full match schedule with team logos, kickoff times, and group details.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sectionItems.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final item = sectionItems[index];
                        if (item is String) {
                          return Text(
                            item,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }

                        final match = item['match'] as MatchModel;
                        final matchNumber = item['matchNumber'] as int;
                        return _MatchCard(
                          key: ValueKey(match.id),
                          match: match,
                          matchNumber: matchNumber,
                          controller: controller,
                        );
                      },
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends StatefulWidget {
  const _MatchCard({
    super.key,
    required this.match,
    required this.matchNumber,
    required this.controller,
  });

  final MatchModel match;
  final int matchNumber;
  final MatchController controller;

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  late final TextEditingController _homeScoreCtrl;
  late final TextEditingController _awayScoreCtrl;
  late final TextEditingController _homeTeamCtrl;
  late final TextEditingController _awayTeamCtrl;
  late List<TextEditingController> _homeGoalCtrl;
  late List<TextEditingController> _awayGoalCtrl;
  bool _saving = false;
  bool _savingTeams = false;
  bool _calculating = false;

  bool get _isKnockout => widget.matchNumber >= 73;

  static List<TextEditingController> _parseScorers(String raw) {
    final parts = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return [TextEditingController()];
    return parts.map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void initState() {
    super.initState();
    _homeScoreCtrl = TextEditingController(text: widget.match.homeScore);
    _awayScoreCtrl = TextEditingController(text: widget.match.awayScore);
    _homeTeamCtrl = TextEditingController(text: widget.match.homeTeam);
    _awayTeamCtrl = TextEditingController(text: widget.match.awayTeam);
    _homeGoalCtrl = _parseScorers(widget.match.homeScorers);
    _awayGoalCtrl = _parseScorers(widget.match.awayScorers);
  }

  @override
  void didUpdateWidget(_MatchCard old) {
    super.didUpdateWidget(old);
    if (old.match.homeScore != widget.match.homeScore) {
      _homeScoreCtrl.text = widget.match.homeScore;
    }
    if (old.match.awayScore != widget.match.awayScore) {
      _awayScoreCtrl.text = widget.match.awayScore;
    }
    if (old.match.homeTeam != widget.match.homeTeam) {
      _homeTeamCtrl.text = widget.match.homeTeam;
    }
    if (old.match.awayTeam != widget.match.awayTeam) {
      _awayTeamCtrl.text = widget.match.awayTeam;
    }
  }

  @override
  void dispose() {
    _homeScoreCtrl.dispose();
    _awayScoreCtrl.dispose();
    _homeTeamCtrl.dispose();
    _awayTeamCtrl.dispose();
    for (final c in _homeGoalCtrl) { c.dispose(); }
    for (final c in _awayGoalCtrl) { c.dispose(); }
    super.dispose();
  }

  void _addHomeGoal() => setState(() => _homeGoalCtrl.add(TextEditingController()));
  void _addAwayGoal() => setState(() => _awayGoalCtrl.add(TextEditingController()));

  void _removeHomeGoal(int i) {
    if (_homeGoalCtrl.length == 1) return;
    setState(() {
      _homeGoalCtrl[i].dispose();
      _homeGoalCtrl.removeAt(i);
    });
  }

  void _removeAwayGoal(int i) {
    if (_awayGoalCtrl.length == 1) return;
    setState(() {
      _awayGoalCtrl[i].dispose();
      _awayGoalCtrl.removeAt(i);
    });
  }

  String get _homeScorersValue =>
      _homeGoalCtrl.map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',');
  String get _awayScorersValue =>
      _awayGoalCtrl.map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(',');

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.controller.updateMatchResult(
      docId: widget.match.id,
      homeScore: _homeScoreCtrl.text.trim(),
      awayScore: _awayScoreCtrl.text.trim(),
      homeScorers: _homeScorersValue,
      awayScorers: _awayScorersValue,
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveTeams() async {
    final home = _homeTeamCtrl.text.trim();
    final away = _awayTeamCtrl.text.trim();
    if (home.isEmpty || away.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال اسمَي الفريقين');
      return;
    }
    setState(() => _savingTeams = true);
    await widget.controller.updateMatchTeams(
      docId: widget.match.id,
      homeTeam: home,
      awayTeam: away,
    );
    if (mounted) setState(() => _savingTeams = false);
  }

  Future<void> _calculate() async {
    setState(() => _calculating = true);
    await widget.controller.calculateMatchPoints(widget.match);
    if (mounted) setState(() => _calculating = false);
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final matchNumber = widget.matchNumber;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── header ───────────────────────────────────────────────────────
          Text(
            'مباراة $matchNumber • FIFA World Cup 2026™ · ${match.dateHeader}, ${match.matchTime}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),

          // ── team badges ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _TeamBadge(
                  logoUrl: match.fixedHomeLogoUrl,
                  teamName: match.homeTeam,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'vs',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: _TeamBadge(
                  logoUrl: match.fixedAwayLogoUrl,
                  teamName: match.awayTeam,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── knockout team names (match 73+) ──────────────────────────────
          if (_isKnockout) ...[
            const Divider(height: 24),
            const Text(
              'أسماء الفرق',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ResultField(
                    controller: _homeTeamCtrl,
                    label: 'الفريق الأول',
                    hint: 'اسم الفريق',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'vs',
                    style: TextStyle(fontSize: 16, color: Colors.black38),
                  ),
                ),
                Expanded(
                  child: _ResultField(
                    controller: _awayTeamCtrl,
                    label: 'الفريق الثاني',
                    hint: 'اسم الفريق',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _savingTeams
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _saveTeams,
                      icon: const Icon(Icons.group, size: 18),
                      label: const Text('حفظ أسماء الفرق'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
            ),
            const Divider(height: 24),
          ],

          // ── score inputs ─────────────────────────────────────────────────
          const Text(
            'أدخل نتيجة المباراة',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ResultField(
                  controller: _homeScoreCtrl,
                  label: match.homeTeam,
                  hint: '0',
                  numeric: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '-',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: _ResultField(
                  controller: _awayScoreCtrl,
                  label: match.awayTeam,
                  hint: '0',
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── scorers ──────────────────────────────────────────────────────
          const Text(
            'أرقام الهدافين',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // home scorers
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      match.homeTeam,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    for (int i = 0; i < _homeGoalCtrl.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _homeGoalCtrl[i],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: 'رقم',
                                  border: const OutlineInputBorder(),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 8),
                                  isDense: true,
                                  suffixIcon: _homeGoalCtrl.length > 1
                                      ? GestureDetector(
                                          onTap: () => _removeHomeGoal(i),
                                          child: const Icon(Icons.close,
                                              size: 16,
                                              color: Colors.black38),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _addHomeGoal,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('إضافة'),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                          padding: EdgeInsets.zero),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // away scorers
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      match.awayTeam,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    for (int i = 0; i < _awayGoalCtrl.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _awayGoalCtrl[i],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: 'رقم',
                                  border: const OutlineInputBorder(),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 8),
                                  isDense: true,
                                  suffixIcon: _awayGoalCtrl.length > 1
                                      ? GestureDetector(
                                          onTap: () => _removeAwayGoal(i),
                                          child: const Icon(Icons.close,
                                              size: 16,
                                              color: Colors.black38),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _addAwayGoal,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('إضافة'),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                          padding: EdgeInsets.zero),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── action buttons ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _saving
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('حفظ النتيجة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _calculating
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _calculate,
                        icon: const Icon(Icons.calculate_outlined, size: 18),
                        label: const Text('احتساب النقاط'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => _StatsSheet(match: widget.match),
              ),
              icon: const Icon(Icons.bar_chart, size: 18),
              label: const Text('إحصائيات التوقعات'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                side: const BorderSide(color: Colors.deepOrange),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── match meta ───────────────────────────────────────────────────
          Text(
            match.matchDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            match.stadiumId.isNotEmpty
                ? 'استاد • ${match.stadiumId}'
                : 'استاد • غير محدد',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          if (match.matchId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'رقم المباراة • ${match.matchId}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            match.homeScore.isNotEmpty || match.awayScore.isNotEmpty
                ? 'النتيجة الحالية: ${match.homeScore} - ${match.awayScore}'
                : 'لم تُسجَّل نتيجة بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: match.homeScore.isNotEmpty || match.awayScore.isNotEmpty
                  ? Colors.green.shade700
                  : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}


class _ResultField extends StatelessWidget {
  const _ResultField({
    required this.controller,
    this.label,
    this.hint = '',
    this.numeric = false,
  });

  final TextEditingController controller;
  final String? label;
  final String hint;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        isDense: true,
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.logoUrl, required this.teamName});

  final String logoUrl;
  final String teamName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: logoUrl.isNotEmpty
                ? Image.network(
                    logoUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.flag, color: Colors.black26, size: 32),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.flag, color: Colors.black26, size: 32),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          teamName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Stats bottom sheet ─────────────────────────────────────────────────────

class _StatsSheet extends StatefulWidget {
  const _StatsSheet({required this.match});
  final MatchModel match;

  @override
  State<_StatsSheet> createState() => _StatsSheetState();
}

class _StatsSheetState extends State<_StatsSheet> {
  bool _loading = true;
  _MatchStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap =
        await FirebaseFirestore.instance.collection('users').get();

    int total = 0, homeWin = 0, draw = 0, awayWin = 0;

    for (final doc in snap.docs) {
      final predictions =
          doc.data()['predictions'] as Map<String, dynamic>?;
      final pred =
          predictions?[widget.match.id] as Map<String, dynamic>?;
      if (pred == null) continue;

      final ph = int.tryParse(pred['home_score']?.toString() ?? '');
      final pa = int.tryParse(pred['away_score']?.toString() ?? '');
      if (ph == null || pa == null) continue;

      total++;
      if (ph > pa) {
        homeWin++;
      } else if (ph == pa) {
        draw++;
      } else {
        awayWin++;
      }
    }

    if (mounted) {
      setState(() {
        _stats = _MatchStats(
          total: total,
          homeWin: homeWin,
          draw: draw,
          awayWin: awayWin,
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // title
          Text(
            '${match.homeTeam}  vs  ${match.awayTeam}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'توقعات المستخدمين',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            )
          else if (_stats == null || _stats!.total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'لا توجد توقعات لهذه المباراة بعد',
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            )
          else
            _StatsBody(match: match, stats: _stats!),
        ],
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.match, required this.stats});
  final MatchModel match;
  final _MatchStats stats;

  @override
  Widget build(BuildContext context) {
    final homePct = stats.homePct;
    final drawPct = stats.drawPct;
    final awayPct = stats.awayPct;

    return Column(
      children: [
        // total count
        Text(
          'إجمالي المتوقعين: ${stats.total} مستخدم',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54),
        ),
        const SizedBox(height: 20),

        // ── three columns: home | draw | away ────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // home
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: match.fixedHomeLogoUrl.isNotEmpty
                        ? Image.network(match.fixedHomeLogoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, e, st) =>
                                const Icon(Icons.flag, size: 32))
                        : const Icon(Icons.flag, size: 32),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    match.homeTeam,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${homePct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${stats.homeWin} صوت',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // draw
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'تعادل',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    '${drawPct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${stats.draw} صوت',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // away
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: match.fixedAwayLogoUrl.isNotEmpty
                        ? Image.network(match.fixedAwayLogoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, e, st) =>
                                const Icon(Icons.flag, size: 32))
                        : const Icon(Icons.flag, size: 32),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    match.awayTeam,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${awayPct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${stats.awayWin} صوت',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── probability bar ──────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (stats.homeWin > 0)
                  Flexible(
                    flex: stats.homeWin,
                    child: Container(color: const Color(0xFF1a1a1a)),
                  ),
                if (stats.draw > 0)
                  Flexible(
                    flex: stats.draw,
                    child: Container(color: Colors.grey.shade400),
                  ),
                if (stats.awayWin > 0)
                  Flexible(
                    flex: stats.awayWin,
                    child: Container(color: Colors.blue),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        // labels under bar
        Row(
          children: [
            Expanded(
              child: Text(
                match.homeTeam,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ),
            const Text(
              'تعادل',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
            Expanded(
              child: Text(
                match.awayTeam,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ),
          ],
        ),

        // ── actual result if available ────────────────────────────────
        if (match.homeScore.isNotEmpty && match.awayScore.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_soccer,
                  size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                'النتيجة الفعلية: ${match.homeScore} - ${match.awayScore}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MatchStats {
  const _MatchStats({
    required this.total,
    required this.homeWin,
    required this.draw,
    required this.awayWin,
  });

  final int total;
  final int homeWin;
  final int draw;
  final int awayWin;

  double get homePct => total > 0 ? homeWin / total * 100 : 0;
  double get drawPct => total > 0 ? draw / total * 100 : 0;
  double get awayPct => total > 0 ? awayWin / total * 100 : 0;
}
