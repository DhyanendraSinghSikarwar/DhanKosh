import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/features/onboarding_permissions/domain/usecases/onboarding_usecases.dart';
import 'package:hisaab/features/onboarding_permissions/domain/validators/onboarding_validators.dart';
import 'package:hisaab/shared/widgets/sms_permission_card.dart';

enum _Step { phone, details, access }

/// First-run gate: name and mobile, optional statement details, then the SMS
/// ask (FR-01-01..08, FR-01-10). Email sign-in arrives with F-03.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _altName = TextEditingController();
  final _altPhone = TextEditingController();
  final _pan = TextEditingController();
  DateTime? _dob;
  _Step _step = _Step.phone;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _altName.dispose();
    _altPhone.dispose();
    _pan.dispose();
    super.dispose();
  }

  OnboardingInput get _input => OnboardingInput(
        name: _name.text,
        phoneDigits: _phone.text,
        dob: _dob,
        pan: _pan.text,
        altName: _altName.text,
        altPhoneDigits: _altPhone.text,
      );

  // FR-01-06: sealed identity first, then profile.
  Future<void> _save({required bool skip}) async {
    setState(() => _saving = true);
    final finish = ref.read(finishOnboardingProvider);
    if (skip) {
      await finish.skip(_input);
    } else {
      await finish(_input);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _step = _Step.access;
    });
  }

  Future<void> _done() async {
    // FR-01-14: the notification ask runs from the lifecycle gate once the
    // gate closes.
    ref.read(onboardingGateProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          children: [
            Icon(Icons.shield_outlined, size: 72, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'DhanKosh',
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Know your money.',
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
            const SizedBox(height: 28),
            switch (_step) {
              _Step.phone => _phoneStep(),
              _Step.details => _detailsStep(),
              _Step.access => _accessStep(),
            },
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Your data never leaves this phone.',
                    style: text.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneStep() {
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _phone]),
      builder: (context, _) {
        final ok = _name.text.trim().isNotEmpty &&
            OnboardingValidators.isValidPhone(_phone.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('welcome-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name (as per bank)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('welcome-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'Mobile (as per bank)',
                prefixText: '+91 ',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('welcome-continue'),
              onPressed:
                  ok ? () => setState(() => _step = _Step.details) : null,
              child: const Text('Continue'),
            ),
            TextButton(
              key: const Key('welcome-skip-setup'),
              onPressed: () => ref.read(onboardingGateProvider.notifier).skip(),
              child: const Text('Skip for now'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailsStep() {
    return ListenableBuilder(
      listenable: _pan,
      builder: (context, _) {
        final validPan = OnboardingValidators.isValidPanOrBlank(_pan.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Unlock your statements',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Optional. Used on this phone to open locked statements.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('welcome-alt-name'),
              controller: _altName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Alternate name'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('welcome-alt-phone'),
              controller: _altPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'Alternate mobile',
                prefixText: '+91 ',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('welcome-dob'),
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                _dob == null
                    ? 'Date of birth'
                    : '${_dob!.day.toString().padLeft(2, '0')}-'
                        '${_dob!.month.toString().padLeft(2, '0')}-${_dob!.year}',
              ),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(1990),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _dob = d);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('welcome-pan'),
              controller: _pan,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(10)],
              decoration: InputDecoration(
                labelText: 'PAN',
                errorText: validPan ? null : 'Format ABCDE1234F',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('welcome-finish'),
              onPressed: validPan && !_saving ? () => _save(skip: false) : null,
              child: const Text('Finish'),
            ),
            TextButton(
              key: const Key('welcome-skip-details'),
              onPressed: _saving ? null : () => _save(skip: true),
              child: const Text('Skip for now'),
            ),
          ],
        );
      },
    );
  }

  Widget _accessStep() {
    final perm = ref.watch(smsPermissionProvider).value;
    final notifier = ref.read(smsPermissionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (perm != null && perm.granted)
          const ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('SMS access allowed'),
          )
        else
          SmsPermissionCard(
            blocked: perm?.blocked ?? false,
            onAllow: () => (perm?.blocked ?? false)
                ? notifier.openAppSettings()
                : notifier.request(),
            onNotNow: _done,
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('welcome-start'),
          onPressed: _done,
          child: const Text('Start'),
        ),
      ],
    );
  }
}
