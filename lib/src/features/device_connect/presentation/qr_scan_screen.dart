import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/device_connect_controller.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final MobileScannerController scannerController = MobileScannerController();
  bool isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => isProcessing = true);
        final String qrDataId = barcode.rawValue!;
        
        try {
          await ref.read(deviceConnectControllerProvider.notifier).scanQR(qrDataId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Request sent! Waiting for approval on the other device...'), 
                backgroundColor: Colors.orange
              ),
            );
            context.pop();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
            setState(() => isProcessing = false);
          }
        }
        break; // Only process the first detect
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCAN DEVICE'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: _onDetect,
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
