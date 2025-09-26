import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'login_page.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _buttonDisabled = false;
  bool _soundAlertActive = false;
  bool _buttonPressAlert = false;
  Timer? _alertCheckTimer;

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse("http://192.168.43.167:81/stream"));

    _alertCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkSoundAlert();
      _checkButtonPressAlert();
    });
  }

  @override
  void dispose() {
    _alertCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSoundAlert() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.43.152/alert'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final isAlertActive = response.body.trim() == '1';
        if (mounted && isAlertActive != _soundAlertActive) {
          setState(() => _soundAlertActive = isAlertActive);

          if (isAlertActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Center(
                    child: Text(
                      '🔔 Alertă! Sunet detectat la ușă!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    )),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Ignorăm erorile
    }
  }

  Future<void> _checkButtonPressAlert() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.43.152/access-request'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final isPressed = response.body.trim() == '1';
        if (mounted && isPressed && !_buttonPressAlert) {
          setState(() => _buttonPressAlert = true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(
                child: Text(
                  '🚪 Cineva a apăsat butonul de acces!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );

          Future.delayed(const Duration(seconds: 10), () {
            if (mounted) setState(() => _buttonPressAlert = false);
          });
        }
      }
    } catch (_) {
      // Ignorăm erorile
    }
  }

  Future<void> _unlockDoor() async {
    if (_buttonDisabled) return;

    setState(() => _buttonDisabled = true);

    try {
      await ApiService().unlockDoor().timeout(const Duration(seconds: 10));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ușa a fost deblocată!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eroare: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _buttonDisabled = false);
      }
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmare'),
        content: const Text('Sigur vrei să te deconectezi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deconectează-te'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  void _refreshStream() {
    _webViewController.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Interfon - Flux video"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reîncarcă fluxul',
            onPressed: _refreshStream,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Deconectare',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_soundAlertActive)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.withOpacity(0.2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'ALERTĂ SUNET ACTIVĂ',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (_buttonPressAlert)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.doorbell_outlined, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'CINEVA ESTE LA UȘĂ!',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _unlockDoor,
            child: _buttonDisabled
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text("🔓 Deblochează ușa"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              textStyle: const TextStyle(fontSize: 18),
              minimumSize: const Size(200, 50),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
