import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool _loading = true;
  String? _error;
  List<_UserEntry> _users = [];

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
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final entries = snap.docs.map((doc) {
        final data = doc.data();
        return _UserEntry(
          name: data['name'] as String? ?? '—',
          points: (data['points'] as num?)?.toInt() ?? 0,
        );
      }).toList()
        ..sort((a, b) => b.points.compareTo(a.points));

      setState(() {
        _users = entries;
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
      appBar: AppBar(
        title: const Text('ترتيب المتوقعين'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
                  ? const Center(child: Text('لا يوجد مستخدمون بعد'))
                  : Column(
                      children: [
                        // ── header row ─────────────────────────────────
                        Container(
                          color: Colors.grey.shade100,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          child: const Row(
                            children: [
                              SizedBox(width: 40),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'الاسم',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                'النقاط',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // ── list ──────────────────────────────────────
                        Expanded(
                          child: ListView.separated(
                            itemCount: _users.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final rank = index + 1;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                child: Row(
                                  children: [
                                    _RankBadge(rank: rank),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: user.points > 0
                                            ? Colors.green.shade50
                                            : user.points < 0
                                                ? Colors.red.shade50
                                                : Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: user.points > 0
                                              ? Colors.green.shade300
                                              : user.points < 0
                                                  ? Colors.red.shade300
                                                  : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        '${user.points} نقطة',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: user.points > 0
                                              ? Colors.green.shade700
                                              : user.points < 0
                                                  ? Colors.red.shade700
                                                  : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    if (rank == 1) {
      bg = const Color(0xFFFFD700);
    } else if (rank == 2) {
      bg = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      bg = const Color(0xFFCD7F32);
    } else {
      bg = Colors.grey.shade200;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Text(
        '$rank',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: rank <= 3 ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}

class _UserEntry {
  const _UserEntry({required this.name, required this.points});
  final String name;
  final int points;
}
