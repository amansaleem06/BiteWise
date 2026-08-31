import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  UserRole _role = UserRole.user;

  @override
  void dispose() {
    _name.dispose();
    _business.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signUp(
          _name.text,
          _email.text,
          _password.text,
          role: _role,
          businessName:
              _role == UserRole.restaurantOwner ? _business.text : null,
        );
    // Navigation is handled by the router's auth redirect.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isBusiness = _role == UserRole.restaurantOwner;

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        AppSnackbar.error(context, userMessageFrom(next.error));
      }
    });

    return AuthScaffold(
      children: [
        Text(AppStrings.signUp, style: theme.textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Choose how you\'ll use TasteWise',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<UserRole>(
          segments: const [
            ButtonSegment(
              value: UserRole.user,
              label: Text('Foodie'),
              icon: Icon(Icons.person_outline_rounded),
            ),
            ButtonSegment(
              value: UserRole.restaurantOwner,
              label: Text('Business'),
              icon: Icon(Icons.storefront_outlined),
            ),
          ],
          selected: {_role},
          onSelectionChanged: (value) => setState(() => _role = value.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: isBusiness
                    ? 'Owner / contact name'
                    : AppStrings.displayName,
                controller: _name,
                validator: Validators.displayName,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              if (isBusiness) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Restaurant / business name',
                  controller: _business,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.length < 2) return 'Enter your business name';
                    if (t.length > 80) return 'Name is too long';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: AppStrings.email,
                controller: _email,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: AppSpacing.md),
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: AppStrings.password,
                      controller: _password,
                      validator: Validators.password,
                      obscure: true,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: AppStrings.confirmPassword,
                      controller: _confirm,
                      validator: (v) =>
                          Validators.confirmPassword(v, _password.text),
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: isBusiness ? 'Create business account' : AppStrings.signUp,
          isLoading: authState.isLoading,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.hasAccountPrompt,
              style: theme.textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: () => context.pushReplacement(Routes.signIn),
              child: const Text(AppStrings.signIn),
            ),
          ],
        ),
      ],
    );
  }
}
