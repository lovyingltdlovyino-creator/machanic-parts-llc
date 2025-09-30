import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  bool _isAdmin = false;

  bool _subscriptionsEnabled = false;
  int _freeCap = 2;

  String? _error;

  // plan_capabilities
  List<Map<String, dynamic>> _plans = const [];

  // Dashboard metrics
  Map<String, dynamic>? _metrics;
  bool _loadingMetrics = false;
  DateTime? _metricsTs;

  // Users list state
  List<Map<String, dynamic>> _users = const [];
  bool _loadingUsers = false;
  final TextEditingController _userSearchCtl = TextEditingController();
  int _userLimit = 25;
  int _userOffset = 0;

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
      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'You must be signed in.';
          _loading = false;
        });
        return;
      }

      // Prefer server-side check via security-definer RPC
      bool isAdmin = false;
      try {
        final r = await _client.rpc('is_current_user_admin');
        if (r is bool && r == true) {
          isAdmin = true;
        }
      } catch (_) {}

      // Fallback to direct profile read if RPC not present yet
      if (!isAdmin) {
        dynamic prof;
        try {
          prof = await _client
              .from('profiles')
              .select('role, user_type, is_admin')
              .eq('id', user.id)
              .maybeSingle();
        } catch (_) {
          prof = null;
        }
        if (prof == null) {
          try {
            prof = await _client
                .from('profiles')
                .select('role, user_type, is_admin')
                .eq('uid', user.id)
                .maybeSingle();
          } catch (_) {}
        }

        if (prof is Map<String, dynamic>) {
          final vIsAdmin = prof['is_admin'];
          final vRole = prof['role'];
          final vUserType = prof['user_type'];
          if (vIsAdmin == true) {
            isAdmin = true;
          } else if (vRole is String && vRole.toLowerCase() == 'admin') {
            isAdmin = true;
          } else if (vUserType is String && vUserType.toLowerCase() == 'admin') {
            isAdmin = true;
          }
        }
      }

      Map<String, dynamic>? config;
      try {
        final cfg = await _client
            .from('app_config')
            .select('subscriptions_enabled, free_cap_override')
            .maybeSingle();
        if (cfg is Map<String, dynamic>) {
          config = cfg;
        } else {
          config = null;
        }
      } catch (_) {
        config = null; // RLS might block; UI will handle
      }

      // Load plan capabilities
      List<dynamic> plans = [];
      try {
        plans = await _client
            .from('plan_capabilities')
            .select('*')
            .order('plan_id');
      } catch (_) {
        plans = [];
      }

      setState(() {
        _isAdmin = isAdmin;
        _subscriptionsEnabled = (config?['subscriptions_enabled'] ?? false) == true;
        _freeCap = (config?['free_cap_override'] ?? 2) as int;
        _plans = List<Map<String, dynamic>>.from(plans);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load admin data: $e';
        _loading = false;
      });
    }

    // After base load, fetch dashboard data
    if (mounted) {
      await Future.wait([
        _loadMetrics(),
        _loadUsers(reset: true),
      ]);
    }
  }

  Future<void> _saveEnabled(bool enabled) async {
    setState(() => _saving = true);
    try {
      await _client.rpc('set_subscriptions_enabled', params: {'_enabled': enabled});
      setState(() => _subscriptionsEnabled = enabled);
      _snack('Updated gating to ${enabled ? 'ENABLED' : 'DISABLED'}');
    } catch (e) {
      _snack('Error updating flag: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _saveFreeCap(int cap) async {
    setState(() => _saving = true);
    try {
      await _client.rpc('set_free_cap', params: {'_cap': cap});
      setState(() => _freeCap = cap);
      _snack('Free cap set to $cap');
    } catch (e) {
      _snack('Error setting free cap: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===================== Dashboard =====================
  Future<void> _loadMetrics() async {
    setState(() { _loadingMetrics = true; });
    try {
      final resp = await _client.rpc('admin_get_metrics');
      if (resp is Map<String, dynamic>) {
        setState(() { _metrics = resp; _metricsTs = DateTime.now(); });
      }
    } catch (e) {
      _snack('Failed to load metrics: $e');
    } finally {
      if (mounted) setState(() { _loadingMetrics = false; });
    }
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (color ?? Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color ?? Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== Users =====================
  Future<void> _loadUsers({bool reset = false}) async {
    if (reset) { _userOffset = 0; _users = const []; }
    setState(() { _loadingUsers = true; });
    try {
      final resp = await _client.rpc('admin_list_users', params: {
        'search': _userSearchCtl.text.trim().isEmpty ? null : _userSearchCtl.text.trim(),
        'p_limit': _userLimit,
        'p_offset': _userOffset,
      });
      if (resp is List) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(resp);
        });
      }
    } catch (e) {
      _snack('Failed to load users: $e');
    } finally {
      if (mounted) setState(() { _loadingUsers = false; });
    }
  }

  Future<void> _toggleBan(String userId, bool block) async {
    try {
      await _client.rpc('admin_set_user_blocked', params: {
        '_user_id': userId,
        '_blocked': block,
        '_reason': block ? 'Manual action from AdminPage' : null,
      });
      _snack(block ? 'User banned' : 'User unbanned');
      await _loadUsers();
    } catch (e) {
      _snack('Failed to update ban: $e');
    }
  }

  Future<void> _openEditPlanDialog(Map<String, dynamic> plan) async {
    final planId = plan['plan_id'] as String;
    final maxListingsCtl = TextEditingController(text: (plan['max_active_listings'] ?? '').toString());
    final rankWeightCtl = TextEditingController(text: (plan['ranking_weight'] ?? '').toString());
    final featuredSlotsCtl = TextEditingController(text: (plan['featured_slots'] ?? '').toString());
    final monthlyBoostsCtl = TextEditingController(text: (plan['monthly_boosts'] ?? '').toString());
    final boostMultiplierCtl = TextEditingController(text: (plan['boost_multiplier'] ?? '').toString());
    final boostHoursCtl = TextEditingController(text: (plan['boost_hours'] ?? '').toString());
    bool leadAccess = (plan['lead_access'] ?? false) == true;
    String analyticsLevel = (plan['analytics_level'] ?? 'none') as String;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit plan: $planId'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _numField('Max active listings', maxListingsCtl),
                const SizedBox(height: 8),
                _numField('Ranking weight', rankWeightCtl),
                const SizedBox(height: 8),
                _numField('Featured slots', featuredSlotsCtl),
                const SizedBox(height: 8),
                _numField('Monthly boosts', monthlyBoostsCtl),
                const SizedBox(height: 8),
                _numField('Boost multiplier', boostMultiplierCtl),
                const SizedBox(height: 8),
                _numField('Boost hours', boostHoursCtl),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Lead access')),
                    StatefulBuilder(
                      builder: (context, setSB) => Switch(
                        value: leadAccess,
                        onChanged: (v) => setSB(() { leadAccess = v; }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Analytics'),
                    const SizedBox(width: 12),
                    StatefulBuilder(
                      builder: (context, setSB) => DropdownButton<String>(
                        value: analyticsLevel,
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(value: 'basic', child: Text('Basic')),
                          DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                        ],
                        onChanged: (v) => setSB(() { if (v != null) analyticsLevel = v; }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        );
      }
    );

    if (result != true) return;

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'max_active_listings': int.tryParse(maxListingsCtl.text.trim()),
        'ranking_weight': double.tryParse(rankWeightCtl.text.trim()),
        'featured_slots': int.tryParse(featuredSlotsCtl.text.trim()),
        'monthly_boosts': int.tryParse(monthlyBoostsCtl.text.trim()),
        'boost_multiplier': double.tryParse(boostMultiplierCtl.text.trim()),
        'boost_hours': int.tryParse(boostHoursCtl.text.trim()),
        'lead_access': leadAccess,
        'analytics_level': analyticsLevel,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _client.from('plan_capabilities').update(payload).eq('plan_id', planId);
      // refresh list
      final plans = await _client.from('plan_capabilities').select('*').order('plan_id');
      setState(() { _plans = List<Map<String, dynamic>>.from(plans); });
      _snack('Updated $planId');
    } catch (e) {
      _snack('Failed to update plan: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  Widget _numField(String label, TextEditingController ctl) {
    return TextFormField(
      controller: ctl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Users', icon: Icon(Icons.people_alt_outlined)),
            Tab(text: 'Settings', icon: Icon(Icons.settings_outlined)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadingMetrics ? null : _loadMetrics,
            tooltip: 'Refresh metrics',
            icon: _loadingMetrics ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
              ? const Center(child: Text('Not authorized. Admins only.'))
              : TabBarView(
                  children: [
                    // ================= Dashboard =================
                    _buildDashboardTab(),
                    // ================= Users =====================
                    _buildUsersTab(),
                    // ================= Settings ==================
                    _buildSettingsTab(),
                  ],
                ),
    ),
    );
  }

  Widget _buildDashboardTab() {
    final m = _metrics ?? const {};
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1400 ? 4 : width >= 1000 ? 3 : width >= 700 ? 2 : 1;

    String fmtNum(dynamic v) {
      if (v == null) return '0';
      if (v is num) return v.toStringAsFixed(0);
      return v.toString();
    }

    String fmtUsd(dynamic v) {
      if (v == null) return '\$0.00';
      if (v is num) {
        // value may be cents; if >= 1000 assume cents
        final isCents = v >= 1000;
        final value = isCents ? (v / 100.0) : v.toDouble();
        return '\$${value.toStringAsFixed(2)}';
      }
      return v.toString();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          GridView.count(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _metricCard(icon: Icons.people_alt, label: 'Users', value: fmtNum(m['total_users'])),
              _metricCard(icon: Icons.store_mall_directory, label: 'Sellers', value: fmtNum(m['sellers'])),
              _metricCard(icon: Icons.person_outline, label: 'Buyers', value: fmtNum(m['buyers'])),
              _metricCard(icon: Icons.admin_panel_settings, label: 'Admins', value: fmtNum(m['admins'])),
              _metricCard(icon: Icons.list_alt, label: 'Listings (active)', value: fmtNum(m['active_listings'])),
              _metricCard(icon: Icons.star, label: 'Featured', value: fmtNum(m['featured_listings'])),
              _metricCard(icon: Icons.block, label: 'Blocked users', value: fmtNum(m['blocked_users']), color: Colors.red),
              _metricCard(icon: Icons.shopping_bag, label: 'Paid subscribers', value: fmtNum(m['paid_subscribers']), color: Colors.green),
              _metricCard(icon: Icons.attach_money, label: 'Est. MRR (USD)', value: fmtUsd(m['estimated_mrr_usd'])),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _metricsTs == null ? '' : 'Updated: ${_metricsTs!.toLocal().toString().split('.')..removeLast()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearchCtl,
                  decoration: const InputDecoration(
                    hintText: 'Search users by email, name, city, state, zip',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadUsers(reset: true),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _loadingUsers ? null : () => _loadUsers(reset: true),
                icon: _loadingUsers
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _users.isEmpty
                ? const Center(child: Text('No users found'))
                : SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('City/State')),
                        DataColumn(label: Text('Plan')),
                        DataColumn(label: Text('Blocked')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _users.map((u) {
                        final email = (u['email'] ?? '').toString();
                        final name = ((u['business_name'] ?? '') as String).isNotEmpty
                            ? u['business_name']
                            : (u['contact_person'] ?? '');
                        final cityState = [u['city'], u['state']].where((e) => (e ?? '').toString().isNotEmpty).join(', ');
                        final plan = (u['active_plan_id'] ?? 'free').toString();
                        final blocked = (u['admin_blocked'] ?? false) == true;
                        return DataRow(cells: [
                          DataCell(Text(email, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(name.toString())),
                          DataCell(Text(cityState)),
                          DataCell(Text(plan.toUpperCase())),
                          DataCell(Icon(blocked ? Icons.block : Icons.check_circle, color: blocked ? Colors.red : Colors.green, size: 18)),
                          DataCell(Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _toggleBan(u['id'].toString(), !blocked),
                                icon: Icon(blocked ? Icons.lock_open : Icons.block),
                                label: Text(blocked ? 'Unban' : 'Ban'),
                              ),
                            ],
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Enable subscriptions gating',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: _subscriptionsEnabled,
                onChanged: _saving ? null : (v) => _saveEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('Free plan listing cap')),
              SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: _freeCap.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  onFieldSubmitted: (v) {
                    final parsed = int.tryParse(v.trim());
                    if (parsed != null && parsed >= 0) {
                      _saveFreeCap(parsed);
                    } else {
                      _snack('Enter a valid number');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Notes:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('- When gating is disabled, all limits are bypassed (non-breaking rollout).'),
          const Text('- Free cap applies only when gating is enabled and plan is Free.'),
          const Divider(height: 32),
          const Text('Plan Capabilities', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          if (_plans.isEmpty)
            const Text('No plan_capabilities rows found.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Plan')),
                  DataColumn(label: Text('Max Listings')),
                  DataColumn(label: Text('Rank Weight')),
                  DataColumn(label: Text('Featured Slots')),
                  DataColumn(label: Text('Monthly Boosts')),
                  DataColumn(label: Text('Boost x')),
                  DataColumn(label: Text('Boost Hours')),
                  DataColumn(label: Text('Lead Access')),
                  DataColumn(label: Text('Analytics')),
                  DataColumn(label: Text('')),
                ],
                rows: _plans.map((p) {
                  return DataRow(cells: [
                    DataCell(Text(p['plan_id'].toString())),
                    DataCell(Text(p['max_active_listings'].toString())),
                    DataCell(Text(p['ranking_weight'].toString())),
                    DataCell(Text(p['featured_slots'].toString())),
                    DataCell(Text(p['monthly_boosts'].toString())),
                    DataCell(Text(p['boost_multiplier'].toString())),
                    DataCell(Text(p['boost_hours'].toString())),
                    DataCell(Icon((p['lead_access'] ?? false) ? Icons.check : Icons.close, size: 18)),
                    DataCell(Text((p['analytics_level'] ?? '').toString())),
                    DataCell(IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _saving ? null : () => _openEditPlanDialog(p),
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
