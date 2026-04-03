import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/signaling_repository.dart';

class CCTVStreamerScreen extends ConsumerStatefulWidget {
  const CCTVStreamerScreen({super.key});

  @override
  ConsumerState<CCTVStreamerScreen> createState() => _CCTVStreamerScreenState();
}

class _CCTVStreamerScreenState extends ConsumerState<CCTVStreamerScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  late SignalingRepository _signaling;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _signaling = SignalingRepository(FirebaseFirestore.instance, FirebaseAuth.instance.currentUser?.uid);
    _startBroadcasting();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  Future<void> _startBroadcasting() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);
    
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'}
    });

    _localRenderer.srcObject = _localStream;

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onIceCandidate = (candidate) {
      _signaling.addIceCandidate(candidate, 'callee_candidates');
    };

    _signaling.watchSession().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      
      if (data['status'] == 'offered' && _peerConnection?.getRemoteDescription() == null) {
        final offer = data['offer'];
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );
        final answer = await _peerConnection?.createAnswer();
        await _peerConnection?.setLocalDescription(answer!);
        await _signaling.sendAnswer(answer!);
      }
    });

    _signaling.watchIceCandidates('caller_candidates').listen((snapshot) {
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
    _localRenderer.dispose();
    _peerConnection?.dispose();
    _localStream?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CCTV BROADCAST ACTIVE')),
      body: Center(
        child: Container(
          width: double.infinity,
          height: 300,
          color: Colors.black,
          child: RTCVideoView(_localRenderer),
        ),
      ),
    );
  }
}
