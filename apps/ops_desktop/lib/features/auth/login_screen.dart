import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../env.dart';

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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionRepositoryProvider).signIn(
            email: _email.text,
            password: _password.text,
          );
      // Navigation is handled by the router redirect on auth state change.
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
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 4,
            child: SafeArea(
              child: Column(
                children: [
                  const Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Padding(
                      padding: EdgeInsets.all(Space.lg),
                      child: LanguageToggle(),
                    ),
                  ),
                  Expanded(child: Center(child: _form(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.signInTitle, style: context.text.headlineMedium),
                const SizedBox(height: Space.xs),
                Text(l.signInSubtitle,
                    style: context.text.bodyMedium?.copyWith(
                      color: c.onSurfaceVariant,
                    )),
                const SizedBox(height: Space.xxl),
                AppField(
                  controller: _email,
                  label: l.email,
                  prefixIcon: Icons.alternate_email_rounded,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  fixedDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? l.enterEmail : null,
                ),
                const SizedBox(height: Space.md),
                AppField(
                  controller: _password,
                  label: l.password,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  fixedDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? l.enterPassword : null,
                  suffix: IconButton(
                    tooltip: _obscure ? l.showPassword : l.hidePassword,
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: Space.lg),
                          child: Container(
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
                                  child: Text(
                                    _describe(_error!),
                                    style: context.text.bodyMedium?.copyWith(
                                      color: c.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: Space.xl),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.onSurfaceVariant,
                            ),
                          )
                        : Text(l.signIn),
                  ),
                ),
                // A developer convenience: never in a release build, whatever it
                // points at.
                if (kDebugMode && Env.isLocal) ...[
                  const SizedBox(height: Space.xl),
                  Text(
                    l.localDatabaseHint,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dark half of the sign-in screen. Stays dark in both themes — it is
/// the brand, not a surface.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const fg = Color(0xFFF2F2F0);
    return Container(
      // An edge so the panel still reads as its own surface in dark mode,
      // where the page behind it is nearly the same ink.
      decoration: BoxDecoration(
        color: const Color(0xFF17181B),
        border: BorderDirectional(
          end: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          // The mark and a drawn stripe rather than the logo image: the
          // image's key bar is black and disappears on this ground.
          const InmoreMark(height: 112, onDark: true),
          const SizedBox(height: 20),
          const CmykStripe(width: 131, height: 5, gap: 7, onDark: true),
          const SizedBox(height: 48),
          Text(
            '${l.appName} ${l.opsTagline}',
            style: context.text.displaySmall?.copyWith(color: fg),
          ),
          const SizedBox(height: Space.sm),
          Text(
            l.brandLine,
            style: context.text.titleMedium?.copyWith(
              color: fg.withValues(alpha: 0.6),
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
