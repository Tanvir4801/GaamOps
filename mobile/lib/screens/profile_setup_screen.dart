import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../models/village_model.dart';
import '../services/auth_service.dart';
import '../services/village_service.dart';
import '../widgets/village_selector_sheet.dart';
import 'customer/customer_main_shell.dart';
import 'saathi/saathi_main_shell.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String uid;
  final String phone;
  final String role;

  const ProfileSetupScreen({
    super.key,
    required this.uid,
    required this.phone,
    required this.role,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  VillageModel? _selectedVillage;
  List<VillageModel> _villages = [];
  bool _loading = false;
  String? _error;

  bool get _isSaathi => widget.role == 'saathi';
  Color get _color => _isSaathi ? AppColors.primaryOrange : AppColors.primaryGreen;

  @override
  void initState() {
    super.initState();
    _loadVillages();
  }

  Future<void> _loadVillages() async {
    final villages = await VillageService.getVillages();
    if (mounted) setState(() => _villages = villages);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (_selectedVillage == null) {
      setState(() => _error = 'Please select your village');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final user = UserModel(
      uid: widget.uid,
      name: name,
      displayName: name,
      phone: widget.phone,
      role: widget.role,
      village: _selectedVillage!.name,
    );

    await AuthService.createUser(user);

    if (!mounted) return;

    if (_isSaathi) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SaathiMainShell()),
        (_) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerMainShell()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _color,
        title: Text('Complete Profile',
            style: TextStyle(color: _color, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSaathi ? '🚗 Saathi Profile' : '👤 Customer Profile',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: _color),
              ),
              const SizedBox(height: 4),
              const Text('Fill in your details to get started',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 32),
              const Text('Full Name',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Enter your full name',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _color),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Home Village',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final village = await VillageSelectorSheet.show(
                    context,
                    villages: _villages,
                  );
                  if (village != null) {
                    setState(() => _selectedVillage = village);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.primaryGreen, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedVillage != null
                              ? '${_selectedVillage!.nameGu} · ${_selectedVillage!.name}'
                              : 'Select your village',
                          style: TextStyle(
                            color: _selectedVillage != null
                                ? AppColors.textDark
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textGrey),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continue / આગળ ચાલો',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
