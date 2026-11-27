import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/block_models.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool registering = false;
  bool busy = false;
  bool showPassword = false;

  @override void dispose() {
    email.dispose(); password.dispose(); name.dispose();
    super.dispose();
  }

  void notice(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> submit() async {
    if (busy || !(form.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      if (registering) {
        final result = await Supabase.instance.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'display_name': ChatValidation.nickname(name.text)},
        );
        if (mounted && result.session == null) {
          notice('Check your email to confirm your account, then sign in.');
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),password:password.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) notice(e.message);
    } catch (_) {
      if (mounted) notice('Could not connect. Check your internet and try again.');
    } finally {
      if (mounted) {
        password.clear();
        setState(() => busy = false);
      }
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Form(key: form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 18),
            Container(
              alignment: Alignment.centerLeft,
              child: const Icon(Icons.holiday_village_rounded,
                size: 60,color: Color(0xFF6CDDCB)),
            ),
            const SizedBox(height: 20),
            Text('Block Chat',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Your neighbourhood, connected privately.',
              style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text('Only invited, administrator-approved members can enter a Block.'),
            const SizedBox(height: 30),
            if (registering) ...[
              TextFormField(
                controller: name,textCapitalization:TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText:'Display name',prefixIcon:Icon(Icons.person_outline)),
                validator: (value) {
                  try { ChatValidation.nickname(value ?? ''); return null; }
                  on FormatException catch (e) { return e.message; }
                },
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: email, keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText:'Email',prefixIcon:Icon(Icons.email_outlined)),
              validator: (value) {
                final emailValue = (value ?? '').trim();
                if (!emailValue.contains('@') || emailValue.length < 5) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller:password,obscureText:!showPassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText:'Password', prefixIcon:const Icon(Icons.lock_outline),
                suffixIcon:IconButton(
                  tooltip: showPassword ? 'Hide password' : 'Show password',
                  icon:Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed:()=>setState(()=>showPassword=!showPassword),
                ),
              ),
              validator:(value)=> (value ?? '').length < 8 ?
                'Use a password of at least 8 characters' : null,
              onFieldSubmitted: (_)=>submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed:busy ? null : submit,
              child:Padding(padding:const EdgeInsets.all(5),
                child:Text(busy ? 'Connecting…' :
                  registering ? 'Create account' : 'Sign in')),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed:busy ? null : ()=>setState(()=>registering=!registering),
              child:Text(registering ?
                'Already have an account? Sign in' :
                'New to Block Chat? Create account'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Messages are visible only to approved members of your Block. '
              'They are not end-to-end encrypted. Do not share sensitive information.',
              style:TextStyle(fontSize:12,color:Colors.white70),
            ),
          ],
        )),
      ),
    ))),
  );
}
