import 'package:flutter/material.dart';
import 'vahan_saathi_registration_screen.dart';
import '../login_screen.dart';

class VahanSaathiChoiceScreen extends StatelessWidget {
  const VahanSaathiChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('પરિવહન સાથી'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text(
                  'નવી નોંધણી\nNew Registration',
                  textAlign: TextAlign.center,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const VahanSaathiRegistrationScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 70,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text(
                  'પહેલેથી એકાઉન્ટ છે\nLogin',
                  textAlign: TextAlign.center,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const LoginScreen(role: 'haul_owner'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}