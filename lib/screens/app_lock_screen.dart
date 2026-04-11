import 'package:flutter/material.dart';
import '../app_lock_service.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController pinController = TextEditingController();

  bool checkingBiometric = false;
  bool unlocking = false;
  String errorText = '';
  bool biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    loadBiometricAvailability();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryBiometricUnlock();
    });
  }

  Future<void> loadBiometricAvailability() async {
    final available = await AppLockService.isBiometricAvailable();
    if (!mounted) return;
    setState(() {
      biometricAvailable = available;
    });
  }

  Future<void> tryBiometricUnlock() async {
    if (checkingBiometric) return;

    setState(() {
      checkingBiometric = true;
      errorText = '';
    });

    final success = await AppLockService.authenticateWithBiometrics();

    if (!mounted) return;

    setState(() {
      checkingBiometric = false;
    });

    if (success) {
      widget.onUnlocked();
    }
  }

  Future<void> unlockWithPin() async {
    final pin = pinController.text.trim();

    if (pin.length < 4) {
      setState(() {
        errorText = 'Please enter your 4-digit PIN';
      });
      return;
    }

    setState(() {
      unlocking = true;
      errorText = '';
    });

    final success = await AppLockService.verifyPin(pin);

    if (!mounted) return;

    setState(() {
      unlocking = false;
    });

    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        errorText = 'Incorrect PIN';
      });
    }
  }

  @override
  void dispose() {
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF4FF), Color(0xFFF8FBFF), Color(0xFFEAF6F4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEFF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 36,
                        color: Color(0xFF2346A0),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'App Locked',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C2434),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use your PIN or biometrics to unlock Prep Buddy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF667085), height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: '4-digit PIN',
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF4F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (errorText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText,
                        style: const TextStyle(
                          color: Color(0xFFE4583E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: unlocking ? null : unlockWithPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2346A0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          unlocking ? 'Unlocking...' : 'Unlock with PIN',
                        ),
                      ),
                    ),
                    if (biometricAvailable) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: checkingBiometric
                              ? null
                              : tryBiometricUnlock,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text(
                            checkingBiometric
                                ? 'Checking...'
                                : 'Use Fingerprint / Face ID',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2346A0),
                            side: const BorderSide(color: Color(0xFF2346A0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
