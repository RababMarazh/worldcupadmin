import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;
  List<_UserData> _users = [];

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
      final snap = await _firestore.collection('users').get();
      final list = snap.docs.map((doc) => _UserData.fromDoc(doc)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── create ──────────────────────────────────────────────────────────────

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final picCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مستخدم جديد'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FormField(
                  controller: nameCtrl,
                  label: 'الاسم',
                  required: true,
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: emailCtrl,
                  label: 'البريد الإلكتروني',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: picCtrl,
                  label: 'رابط الصورة الشخصية',
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('إنشاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uid = _generateCode();
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': nameCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'profilePictureUrl': picCtrl.text.trim(),
      'expectations': [],
      'predictions': {},
      'points': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await Clipboard.setData(ClipboardData(text: uid));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء المستخدم • الكود: $uid (تم نسخه)'),
          backgroundColor: Colors.green,
        ),
      );
    }

    _load();
  }

  // ── edit ─────────────────────────────────────────────────────────────────

  Future<void> _showEditDialog(_UserData user) async {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final picCtrl = TextEditingController(text: user.profilePictureUrl);
    final pointsCtrl = TextEditingController(text: user.points.toString());
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل: ${user.name}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // uid (read-only, copyable)
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: user.uid));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('تم نسخ الكود')),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.copy, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الكود: ${user.uid}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: nameCtrl,
                  label: 'الاسم',
                  required: true,
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: emailCtrl,
                  label: 'البريد الإلكتروني',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: picCtrl,
                  label: 'رابط الصورة الشخصية',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: pointsCtrl,
                  label: 'النقاط',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _firestore.collection('users').doc(user.uid).update({
      'name': nameCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'profilePictureUrl': picCtrl.text.trim(),
      'points': int.tryParse(pointsCtrl.text.trim()) ?? user.points,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث بيانات المستخدم'),
          backgroundColor: Colors.blue,
        ),
      );
    }

    _load();
  }

  // ── delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(_UserData user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            children: [
              const TextSpan(text: 'هل تريد حذف المستخدم '),
              TextSpan(
                text: user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' نهائياً؟\nلا يمكن التراجع عن هذا الإجراء.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _firestore.collection('users').doc(user.uid).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف ${user.name}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    _load();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _generateCode() {
    final digits = Random.secure().nextInt(900000) + 100000;
    return 'WC$digits';
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة المستخدمين (${_users.length})'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('مستخدم جديد'),
        backgroundColor: Colors.green,
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
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _users.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return _UserCard(
                          user: user,
                          onEdit: () => _showEditDialog(user),
                          onDelete: () => _confirmDelete(user),
                        );
                      },
                    ),
    );
  }
}

// ── user card ──────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  final _UserData user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── avatar ─────────────────────────────────────────────────
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.green.shade100,
              backgroundImage: user.profilePictureUrl.isNotEmpty
                  ? NetworkImage(user.profilePictureUrl)
                  : null,
              onBackgroundImageError:
                  user.profilePictureUrl.isNotEmpty ? (_, _) {} : null,
              child: user.profilePictureUrl.isEmpty
                  ? Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // ── info ───────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (user.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Chip(
                        label: user.uid,
                        icon: Icons.key,
                        onTap: () async {
                          await Clipboard.setData(
                              ClipboardData(text: user.uid));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ الكود')),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _Chip(
                        label: '${user.points} نقطة',
                        icon: Icons.star,
                        color: user.points > 0
                            ? Colors.green.shade700
                            : Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'انضم: ${_formatDate(user.createdAt)}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ],
              ),
            ),

            // ── actions ────────────────────────────────────────────────
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'تعديل',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'حذف',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

// ── small chip ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Colors.black54;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: fg,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── reusable form field ────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    this.required = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null
          : null,
    );
  }
}

// ── data class ─────────────────────────────────────────────────────────────

class _UserData {
  const _UserData({
    required this.uid,
    required this.name,
    required this.email,
    required this.profilePictureUrl,
    required this.points,
    required this.createdAt,
  });

  factory _UserData.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return _UserData(
      uid: doc.id,
      name: d['name'] as String? ?? '—',
      email: d['email'] as String? ?? '',
      profilePictureUrl: d['profilePictureUrl'] as String? ?? '',
      points: (d['points'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String uid;
  final String name;
  final String email;
  final String profilePictureUrl;
  final int points;
  final DateTime? createdAt;
}
