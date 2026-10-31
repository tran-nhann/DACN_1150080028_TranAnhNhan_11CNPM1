import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _password = TextEditingController();
  bool _hidden = true;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!ref.read(authProvider).busy && validateAndReveal(context, _form)) {
      ref
          .read(authProvider.notifier)
          .login(_username.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Brand(),
                          const SizedBox(height: 48),
                          Text(
                            'Đăng nhập',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            key: const Key('login_username'),
                            controller: _username,
                            enabled: !auth.busy,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Tài khoản',
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Nhập tài khoản.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('login_password'),
                            controller: _password,
                            enabled: !auth.busy,
                            obscureText: _hidden,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _hidden
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () =>
                                    setState(() => _hidden = !_hidden),
                                icon: Icon(
                                  _hidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Nhập mật khẩu.'
                                : null,
                          ),
                          if (auth.error != null) ...[
                            const SizedBox(height: 16),
                            InlineError(
                              auth.error!,
                              key: const Key('login_error'),
                            ),
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: PressScale(
                              child: FilledButton(
                                key: const Key('login_submit'),
                                onPressed: auth.busy ? null : _submit,
                                child: auth.busy
                                    ? const AsterLoader(
                                        size: 24,
                                        color: Colors.white,
                                      )
                                    : const Text('Đăng nhập'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
