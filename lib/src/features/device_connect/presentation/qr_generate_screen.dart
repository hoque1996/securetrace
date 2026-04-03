import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/device_connect_controller.dart';
import '../domain/device_link_request.dart';

class QrGenerateScreen extends ConsumerStatefulWidget {
  const QrGenerateScreen({super.key});

  @override
  ConsumerState<QrGenerateScreen> createState() => _QrGenerateScreenState();
}

class _QrGenerateScreenState extends ConsumerState<QrGenerateScreen> {
  DeviceLinkRequest? _request;
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _startGeneration();
  }

  Future<void> _startGeneration() async {
    final req = await ref.read(deviceConnectControllerProvider.notifier).generateQR();
    if (mounted) {
      setState(() {
        _request = req;
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating || _request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('LINK DEVICE')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final linkStream = ref.watch(linkRequestStreamProvider(_request!.id));

    return Scaffold(
      appBar: AppBar(title: const Text('LINK DEVICE')),
      body: linkStream.when(
        loading: () => _buildQrView(_request!.id),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (liveRequest) {
          if (liveRequest == null) return const Center(child: Text('Request not found or deleted'));

          if (liveRequest.status == 'approved') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device Linked Successfully!')));
                context.pop();
              }
            });
            return const Center(child: Text('Linked successfully!', style: TextStyle(color: Colors.green, fontSize: 24)));
          }

          if (liveRequest.status == 'awaiting_approval') {
            return _buildApprovalView(liveRequest);
          }

          if (liveRequest.expiresAt.isBefore(DateTime.now())) {
            return const Center(child: Text('QR Code Expired. Please try again.', style: TextStyle(color: Colors.red)));
          }

          return _buildQrView(liveRequest.id);
        },
      ),
    );
  }

  Widget _buildQrView(String qrDataId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Scan this QR code from the Tracking Device',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This code expires in 5 minutes for security purposes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: qrDataId,
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalView(DeviceLinkRequest request) {
    final controller = ref.read(deviceConnectControllerProvider.notifier);
    final state = ref.watch(deviceConnectControllerProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Connection Request Detected!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Device ID: ${request.deviceBId} wants to link.', textAlign: TextAlign.center),
            const SizedBox(height: 40),
            if (state.isLoading) 
              const CircularProgressIndicator()
            else 
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      await controller.reject(request.id);
                      if (mounted) context.pop();
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                  ElevatedButton(
                    onPressed: () => controller.approve(request.id),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Approve Link'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
