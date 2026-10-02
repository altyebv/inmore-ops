import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describe(Object e) {
    final l = context.l10n;
    if (e is AuthException &&
        (e.code == 'invalid_credentials' || e.statusCode == '400')) {
      return l.invalidCredentials;
    }
    return AppError.from(e).message(l);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    const brand = Color(0xFF17181B);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: brand,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 8, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: LanguageToggle(foreground: Color(0xFFF2F2F0)),
                      ),
                      const SizedBox(height: 28),
                      const InmoreMark(height: 64, onDark: true),
                      const SizedBox(height: 14),
                      const CmykStripe(
                          width: 75, height: 4, gap: 5, onDark: true),
                      const SizedBox(height: 28),
                      Text(
                        l.appName,
                        style: context.text.headlineMedium
                            ?.copyWith(color: const Color(0xFFF2F2F0)),
                      ),
                      Text(
                        l.ownerTagline,
                        style: context.text.titleMedium?.copyWith(
                          color: const Color(0xFFF2F2F0).withValues(alpha: 0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.signInTitle, style: context.text.titleLarge),
                      const SizedBox(height: 4),
                      Text(l.signInSubtitle,
                          style: context.text.bodyMedium
                              ?.copyWith(color: c.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      AppField(
                        controller: _email,
                        label: l.email,
                        prefixIcon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        fixedDirection: TextDirection.ltr,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) => (v == null || !v.contains('@'))
                            ? l.enterEmail
                            : null,
                      ),
                      const SizedBox(height: Space.md),
                      AppField(
                        controller: _password,
                        label: l.password,
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscure,
                        fixedDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? l.enterPassword : null,
                        suffix: IconButton(
                          tooltip: _obscure ? l.showPassword : l.hidePassword,
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Space.lg),
                        Container(
                          padding: const EdgeInsets.all(Space.md),
                          decoration: BoxDecoration(
                            color: c.errorContainer,
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 18, color: c.onErrorContainer),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Text(_describe(_error!),
                                    style: context.text.bodyMedium
                                        ?.copyWith(color: c.onErrorContainer)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: Space.xl),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: c.onSurfaceVariant,
                                  ),
                                )
                              : Text(l.signIn),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
