import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import '../controllers/match_controller.dart';
import '../controllers/user_controller.dart';
import '../models/match_model.dart';
import 'expectations_page.dart';
import 'leaderboard_page.dart';

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
            icon: const Icon(Icons.leaderboard),
            tooltip: 'الترتيب',
            onPressed: () => Get.to(() => const LeaderboardPage()),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Show dialog to create user with generated code
          final nameController = TextEditingController();
          await showDialog<void>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Add User'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a name')),
                        );
                        return;
                      }

                      final code = await userController.createUser(name);
                      if (code != null) {
                        await Clipboard.setData(ClipboardData(text: code));
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('User created. Code copied: $code'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to create user'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Generate & Copy'),
                  ),
                ],
              );
            },
          );
        },
        label: const Text('اضافة'),
        icon: const Icon(Icons.lightbulb),
        backgroundColor: Colors.green,
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
  bool _saving = false;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    _homeScoreCtrl = TextEditingController(text: widget.match.homeScore);
    _awayScoreCtrl = TextEditingController(text: widget.match.awayScore);
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
  }

  @override
  void dispose() {
    _homeScoreCtrl.dispose();
    _awayScoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.controller.updateMatchResult(
      docId: widget.match.id,
      homeScore: _homeScoreCtrl.text.trim(),
      awayScore: _awayScoreCtrl.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
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
