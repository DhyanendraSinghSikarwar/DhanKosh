import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/profile_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/onboarding_permissions/domain/validators/onboarding_validators.dart';
import 'package:hisaab/features/profile/domain/profile_draft.dart';
import 'package:hisaab/features/profile/presentation/bank_details_sheet.dart';
import 'package:hisaab/features/profile/presentation/photo_crop_screen.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/profile_avatar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parser_core/parser_core.dart' show AccountKind;

/// Profile: personal details and per-bank unlock details (F-27;
/// FR-27-06, FR-27-07, FR-27-08, FR-27-13, FR-27-15).
class ProfileScreen extends ConsumerWidget {
  /// Creates the screen.
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileDataProvider);
    final id = ref.watch(identityDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: p.hasValue && id.hasValue
          ? _Form(profile: p.requireValue, identity: id.value)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.profile, required this.identity});

  final UserProfile profile;
  final Identity? identity;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _name = TextEditingController(
    text: widget.profile.name ?? widget.identity?.name ?? '',
  );
  late final _mobile = TextEditingController(
    text: OnboardingValidators.phoneDigits(
      widget.profile.phone ?? widget.identity?.phone ?? '',
    ),
  );
  late final _email = TextEditingController(
    text: widget.profile.email ?? widget.identity?.email ?? '',
  );
  late final _occupation =
      TextEditingController(text: widget.profile.occupation ?? '');
  late final _pan = TextEditingController(text: widget.identity?.pan ?? '');
  late final List<String> _altNames = [...?widget.identity?.allAltNames];
  late final List<String> _altPhones = [...?widget.identity?.allAltPhones];
  final _altName = TextEditingController();
  final _altPhone = TextEditingController();
  String? _photo;
  late DateTime? _dob = widget.identity?.dob;
  late final String _initial = _snapshot();
  late final String? _photoAtStart = widget.profile.photoPath;
  bool _saving = false;

  String _snapshot() => [
        _name.text,
        _mobile.text,
        _email.text,
        _occupation.text,
        _pan.text,
        _dob?.toIso8601String(),
        _altNames.join(','),
        _altPhones.join(','),
      ].join('|');

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _occupation.dispose();
    _pan.dispose();
    _altName.dispose();
    _altPhone.dispose();
    super.dispose();
  }

  bool get _mobileValid =>
      _mobile.text.isEmpty || OnboardingValidators.isValidPhone(_mobile.text);

  ProfileDraft get _draft => ProfileDraft(
        name: _name.text,
        pan: _pan.text,
        dirty: _snapshot() != _initial,
      );

  bool get _canSave => _draft.canSave && _mobileValid && !_saving;

  Future<void> _save() async {
    setState(() => _saving = true);
    final phone = _mobile.text.isEmpty
        ? null
        : OnboardingValidators.formatPhone(_mobile.text);
    final email = _email.text.trim().isEmpty ? null : _email.text.trim();
    // Sealed identity first, then the plain profile (FR-27-05).
    await ref.read(identityRepositoryProvider).save(
          Identity(
            name: _name.text.trim(),
            dob: _dob,
            pan: _pan.text.isEmpty ? null : _pan.text,
            phone: phone,
            altName: _altNames.isEmpty ? null : _altNames.first,
            altPhone: _altPhones.isEmpty ? null : _altPhones.first,
            moreNames: _altNames.skip(1).toList(),
            morePhones: _altPhones.skip(1).toList(),
            email: email,
          ),
        );
    await ref.read(profileRepositoryProvider).save(
          UserProfile(
            name: _name.text.trim(),
            email: email,
            phone: phone,
            occupation: _occupation.text.trim(),
            photoPath: _photo ?? _photoAtStart,
          ),
        );
    ref
      ..invalidate(profileDataProvider)
      ..invalidate(identityDataProvider)
      ..read(onboardingGateProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved')));
    Navigator.of(context).maybePop();
  }

  String? get _photoPath => _photo ?? _photoAtStart;

  /// Picks, adjusts and saves the photo at once (FR-27-09).
  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final png = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => PhotoCropScreen(bytes: bytes)),
    );
    if (png == null) return;
    await ref.read(setProfilePhotoProvider).set(png);
    final p = await ref.read(profileRepositoryProvider).read();
    ref.invalidate(profileDataProvider);
    if (mounted) setState(() => _photo = p.photoPath);
  }

  Future<void> _removePhoto() async {
    await ref.read(setProfilePhotoProvider).clear();
    ref.invalidate(profileDataProvider);
    if (mounted) setState(() => _photo = '');
  }

  void _addAltName() {
    final v = _altName.text.trim();
    if (v.isEmpty || _altNames.contains(v)) return;
    setState(() {
      _altNames.add(v);
      _altName.clear();
    });
  }

  void _addAltPhone() {
    final d = OnboardingValidators.phoneDigits(_altPhone.text);
    if (!OnboardingValidators.isValidPhone(d)) return;
    final v = OnboardingValidators.formatPhone(d)!;
    if (_altPhones.contains(v)) return;
    setState(() {
      _altPhones.add(v);
      _altPhone.clear();
    });
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _dob = d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: 12);
    final count = ref.watch(bankIdentitiesProvider).value?.length ?? 0;
    final pw = ref.watch(savedPasswordCountProvider).value ?? 0;
    final accounts = ref.watch(_bankAccountsProvider).value ?? const [];
    final panOk = _draft.panValid;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Column(
          children: [
            ProfileAvatar(
              name: _name.text,
              photoPath: _photoPath,
              radius: 44,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const Key('profile-photo-change'),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    (_photoPath ?? '').isEmpty ? 'Add photo' : 'Change photo',
                  ),
                  onPressed: _changePhoto,
                ),
                if ((_photoPath ?? '').isNotEmpty)
                  TextButton(
                    key: const Key('profile-photo-remove'),
                    onPressed: _removePhoto,
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Personal', style: theme.textTheme.titleSmall),
              gap,
              TextField(
                key: const Key('profile-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full name (as per bank)',
                  errorText: _draft.nameValid ? null : 'Required',
                ),
                onChanged: (_) => setState(() {}),
              ),
              gap,
              TextField(
                key: const Key('profile-mobile'),
                controller: _mobile,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile',
                  prefixText: '+91 ',
                  errorText: _mobileValid ? null : 'Enter 10 digits',
                ),
                onChanged: (_) => setState(() {}),
              ),
              gap,
              TextField(
                key: const Key('profile-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: (_) => setState(() {}),
              ),
              gap,
              TextField(
                key: const Key('profile-occupation'),
                controller: _occupation,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Occupation'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('For locked statements', style: theme.textTheme.titleSmall),
              gap,
              ListTile(
                key: const Key('profile-dob'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Date of birth'),
                subtitle: Text(
                  _dob == null
                      ? 'Not set'
                      : _dob!.toIso8601String().substring(0, 10),
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDob,
              ),
              TextField(
                key: const Key('profile-pan'),
                controller: _pan,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'PAN',
                  counterText: '',
                  errorText: panOk ? null : 'Format ABCDE1234F',
                ),
                onChanged: (v) {
                  final up = v.toUpperCase();
                  if (up != v) {
                    _pan.value = TextEditingValue(
                      text: up,
                      selection: TextSelection.collapsed(offset: up.length),
                    );
                  }
                  setState(() {});
                },
              ),
              gap,
              Text('Other names as per bank', style: theme.textTheme.bodySmall),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in _altNames)
                    InputChip(
                      key: Key('alt-name-$n'),
                      label: Text(n),
                      onDeleted: () => setState(() => _altNames.remove(n)),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('profile-alt-name'),
                      controller: _altName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Add a name',
                      ),
                      onSubmitted: (_) => _addAltName(),
                    ),
                  ),
                  IconButton(
                    key: const Key('profile-alt-name-add'),
                    tooltip: 'Add name',
                    icon: const Icon(Icons.add),
                    onPressed: _addAltName,
                  ),
                ],
              ),
              gap,
              Text(
                'Other mobiles as per bank',
                style: theme.textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in _altPhones)
                    InputChip(
                      key: Key('alt-phone-$n'),
                      label: Text(n),
                      onDeleted: () => setState(() => _altPhones.remove(n)),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('profile-alt-phone'),
                      controller: _altPhone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Add a mobile',
                        prefixText: '+91 ',
                      ),
                      onSubmitted: (_) => _addAltPhone(),
                    ),
                  ),
                  IconButton(
                    key: const Key('profile-alt-phone-add'),
                    tooltip: 'Add mobile',
                    icon: const Icon(Icons.add),
                    onPressed: _addAltPhone,
                  ),
                ],
              ),
              gap,
              ListTile(
                key: const Key('profile-bank-details'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Bank details'),
                subtitle: Text(
                  '$count saved  ·  $pw statement '
                  '${pw == 1 ? 'password' : 'passwords'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => BankDetailsListSheet(accounts: accounts),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('profile-save'),
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
        const SizedBox(height: 12),
        Text(
          'Stored encrypted on this device only.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

final _bankAccountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchVisible().map(
        (l) => l.where((a) => a.kind == AccountKind.account).toList(),
      ),
);
