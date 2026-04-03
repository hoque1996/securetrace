import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/signaling_repository.dart';

class CCTVViewerScreen extends ConsumerStatefulWidget {
  const CCTVViewerScreen({super.key});

  @override
  ConsumerState<CCTVViewerScreen> createState() => _CCTVViewerScreenState();
}

class _CCTVViewerScreenState extends ConsumerState<CCTVViewerScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  late SignalingRepository _signaling;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _signaling = SignalingRepository(FirebaseFirestore.instance, FirebaseAuth.instance.currentUser?.uid);
    _connectToStream();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
  }

  Future<void> _connectToStream() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
      }
    };

    _peerConnection?.onIceCandidate = (candidate) {
      _signaling.addIceCandidate(candidate, 'caller_candidates');
    };

    final offer = await _peerConnection?.createOffer();
    await _peerConnection?.setLocalDescription(offer!);
    await _signaling.sendOffer(offer!);

    _signaling.watchSession().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      
      if (data['status'] == 'answered' && _peerConnection?.getRemoteDescription() == null) {
        final answer = data['answer'];
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
      }
    });

    _signaling.watchIceCandidates('callee_candidates').listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          _peerConnection?.addCandidate(
            RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REMOTE CCTV VIEW')),
      body: Center(
        child: Container(
          width: double.infinity,
          height: 300,
          color: Colors.black,
          child: RTCVideoView(_remoteRenderer),
        ),
      ),
    );
  }
}
