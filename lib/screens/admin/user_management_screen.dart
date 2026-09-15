import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/phone_auth.dart';
import '../../models/user_model.dart';
import '../../services/firebase/admin_user_service.dart';

/// Admin view of every account: search, add, edit, approve and deactivate.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _search = TextEditingController();

  String _query = '';
  UserRole? _role;
  AccountStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add user'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search name, email or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          _Filters(
            role: _role,
            status: _status,
            onRole: (value) => setState(() => _role = value),
            onStatus: (value) => setState(() => _status = value),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load accounts.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final accounts = _visible(snapshot.data!.docs);
                if (accounts.isEmpty) {
                  return Center(
                    child: Text(
                      snapshot.data!.docs.isEmpty
                          ? 'No accounts yet.'
                          : 'No accounts match this search.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _UserCard(account: accounts[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Filtering and sorting happen here rather than in the query, so no
  /// composite index is needed for what is a small collection.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visible(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final needle = _query.trim().toLowerCase();

    final matches = docs.where((doc) {
      final data = doc.data();
      if (_role != null && UserRole.fromStoredValue(data['role']) != _role) {
        return false;
      }
      if (_status != null &&
          AccountStatus.fromStoredValue(data['status']) != _status) {
        return false;
      }
      if (needle.isEmpty) return true;
      return [data['name'], data['email'], data['phone']].any(
        (field) => field?.toString().toLowerCase().contains(needle) == true,
      );
    }).toList();

    matches.sort((a, b) {
      final aName = (a.data()['name'] ?? '').toString().toLowerCase();
      final bName = (b.data()['name'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });
    return matches;
  }

  Future<void> _addUser() async {
    final created = await showAddUserDialog(context);
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account created.')));
  }
}

/// Opens the add-user form. Returns the new uid, or null if cancelled.
Future<String?> showAddUserDialog(
  BuildContext context, {
  String? initialEmail,
  String? initialPhone,
  UserRole? initialRole,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AddUserDialog(
      initialEmail: initialEmail,
      initialPhone: initialPhone,
      initialRole: initialRole,
    ),
  );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.role,
    required this.status,
    required this.onRole,
    required this.onStatus,
  });

  final UserRole? role;
  final AccountStatus? status;
  final ValueChanged<UserRole?> onRole;
  final ValueChanged<AccountStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: role == null && status == null,
            onSelected: (_) {
              onRole(null);
              onStatus(null);
            },
          ),
          const SizedBox(width: 8),
          for (final value in UserRole.values) ...[
            FilterChip(
              label: Text(value.label),
              selected: role == value,
              onSelected: (selected) => onRole(selected ? value : null),
            ),
            const SizedBox(width: 8),
          ],
          for (final value in [
            AccountStatus.pending,
            AccountStatus.suspended,
          ]) ...[
            FilterChip(
              label: Text(value.label),
              selected: status == value,
              onSelected: (selected) => onStatus(selected ? value : null),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  const _UserCard({required this.account});

  final QueryDocumentSnapshot<Map<String, dynamic>> account;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _busy = false;

  bool get _isSelf =>
      FirebaseAuth.instance.currentUser?.uid == widget.account.id;

  @override
  Widget build(BuildContext context) {
    final data = widget.account.data();
    final role = UserRole.fromStoredValue(data['role']);
    final status = AccountStatus.fromStoredValue(data['status']);
    final name = data['name']?.toString().trim();
    final email = displayEmail(data['email']?.toString());
    final phone = data['phone']?.toString().trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name?.isNotEmpty == true ? name! : 'Unnamed account',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (_isSelf)
                        const _Badge(label: 'You', color: AppColors.primary),
                    ],
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  Text(
                    phone.isEmpty ? 'No phone number' : '+91 $phone',
                    style: TextStyle(
                      fontSize: 12,
                      color: phone.isEmpty
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Badge(label: role.label, color: AppColors.primary),
                      _Badge(
                        label: status.label,
                        color: switch (status) {
                          AccountStatus.active => AppColors.success,
                          AccountStatus.pending => AppColors.warning,
                          AccountStatus.rejected ||
                          AccountStatus.suspended => AppColors.error,
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _busy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : PopupMenuButton<String>(
                    tooltip: 'Manage account',
                    onSelected: _onAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (status == AccountStatus.pending)
                        const PopupMenuItem(
                          value: 'approve',
                          child: Text('Approve'),
                        ),
                      if (email.isNotEmpty)
                        const PopupMenuItem(
                          value: 'reset',
                          child: Text('Send password reset'),
                        ),
                      // An admin deactivating themselves would be locked out
                      // with nobody able to undo it.
                      if (!_isSelf)
                        status == AccountStatus.active ||
                                status == AccountStatus.pending
                            ? const PopupMenuItem(
                                value: 'deactivate',
                                child: Text('Deactivate'),
                              )
                            : const PopupMenuItem(
                                value: 'activate',
                                child: Text('Reactivate'),
                              ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  void _message(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : null,
      ),
    );
  }

  Future<void> _onAction(String action) async {
    switch (action) {
      case 'edit':
        await _edit();
      case 'approve':
        await _setStatus(AccountStatus.active, 'Account approved.');
      case 'activate':
        await _setStatus(AccountStatus.active, 'Account reactivated.');
      case 'deactivate':
        await _confirmDeactivate();
      case 'reset':
        await _sendReset();
    }
  }

  Future<void> _edit() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditUserDialog(account: widget.account, isSelf: _isSelf),
    );
    if (saved == true) _message('Account updated.');
  }

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate account?'),
        content: const Text(
          'They stay signed in but cannot browse, order or fulfil anything, '
          'and are shown a notice explaining access was withdrawn. This can '
          'be reversed at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _setStatus(AccountStatus.suspended, 'Account deactivated.');
  }

  Future<void> _setStatus(AccountStatus status, String success) async {
    setState(() => _busy = true);
    try {
      await widget.account.reference.update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(success);
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'Only an admin can change an account.'
            : 'Could not update the account.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendReset() async {
    final email = widget.account.data()['email']?.toString() ?? '';
    setState(() => _busy = true);
    try {
      await AdminUserService().sendPasswordReset(email);
      _message('Password reset email sent to $email.');
    } on AdminUserException catch (error) {
      _message(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.account, required this.isSelf});

  final QueryDocumentSnapshot<Map<String, dynamic>> account;
  final bool isSelf;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late UserRole _role;
  late AccountStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.account.data();
    _name = TextEditingController(text: data['name']?.toString() ?? '');
    _phone = TextEditingController(text: data['phone']?.toString() ?? '');
    _email = TextEditingController(
      text: displayEmail(data['email']?.toString()),
    );
    _role = UserRole.fromStoredValue(data['role']);
    _status = AccountStatus.fromStoredValue(data['status']);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit account'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address (optional)',
                  ),
                  validator: optionalEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Enter their full name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixText: '+91 ',
                    counterText: '',
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  // Changing your own role could remove your admin access.
                  onChanged: widget.isSelf
                      ? null
                      : (value) => setState(() => _role = value!),
                  items: [
                    for (final value in UserRole.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  onChanged: widget.isSelf
                      ? null
                      : (value) => setState(() => _status = value!),
                  items: [
                    for (final value in AccountStatus.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                ),
                if (widget.isSelf) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Role and status are locked on your own account, so you '
                    'cannot lock yourself out.',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.account.reference.update({
        'name': _name.text.trim(),
        'email': displayEmail(_email.text),
        'phone': _phone.text.replaceAll(RegExp(r'\D'), ''),
        'role': _role.name,
        'status': _status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Only an admin can change an account.'
                : 'Could not save the account.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog({
    this.initialEmail,
    this.initialPhone,
    this.initialRole,
  });

  final String? initialEmail;
  final String? initialPhone;
  final UserRole? initialRole;

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhone ?? '',
  );
  late UserRole _role = widget.initialRole ?? UserRole.customer;
  final _initialPassword = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _initialPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add user'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email is optional. With an email they receive a link to '
                  'set their own password. Without one they sign in with '
                  'their mobile number and the password you set here.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Enter their full name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email address (optional)',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: optionalEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixText: '+91 ',
                    counterText: '',
                  ),
                  validator: _validatePhone,
                ),
                if (displayEmail(_email.text).isEmpty) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _initialPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Initial password',
                      helperText:
                          'Share this once. They sign in with their mobile '
                          'number.',
                    ),
                    validator: (value) {
                      if (displayEmail(_email.text).isNotEmpty) return null;
                      if ((value ?? '').length < 6) {
                        return 'At least 6 characters';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  onChanged: (value) => setState(() => _role = value!),
                  items: [
                    for (final value in UserRole.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create account'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final uid = await AdminUserService().createAccount(
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        role: _role,
        initialPassword: displayEmail(_email.text).isEmpty
            ? _initialPassword.text
            : null,
      );
      if (!mounted) return;
      Navigator.pop(context, uid);
    } on AdminUserException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

/// Every persona needs a reachable number, so this is never optional.
String? _validatePhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length != 10) return 'Enter a valid 10-digit mobile number';
  return null;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
