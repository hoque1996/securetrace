import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isBackingUp = false;
  bool _autoSyncEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSyncSettings();
  }

  Future<void> _loadSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
    });
  }

  Future<void> _toggleAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', value);
    setState(() => _autoSyncEnabled = value);
  }
  
  Future<void> _backupContacts() async {
    setState(() => _isBackingUp = true);
    
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
      if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
        final contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.phone, ContactProperty.email},
        );
        
        final contactList = contacts.map((c) => {
          'id': c.id,
          'displayName': c.displayName,
          'phones': c.phones.map((p) => p.number).toList(),
          'emails': c.emails.map((e) => e.address).toList(),
        }).toList();

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('backups')
            .doc('contacts')
            .set({
              'last_backup': FieldValue.serverTimestamp(),
              'total_contacts': contacts.length,
              'data': contactList,
            });
            
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contacts backed up successfully!'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _backupMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _isBackingUp = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          for (final file in result.files) {
            if (file.path == null) continue;
            
            final fileName = file.name;
            final storageRef = FirebaseStorage.instance
              .ref()
              .child('users/${user.uid}/backups/$fileName');
              
            await storageRef.putFile(File(file.path!));
            
            // Log to Firestore for vault index
            await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('backups')
              .doc('media_index')
              .set({
                'files': FieldValue.arrayUnion([{
                  'name': fileName,
                  'type': file.extension,
                  'size': file.size,
                  'timestamp': FieldValue.serverTimestamp(),
                  'url': await storageRef.getDownloadURL(),
                }])
              }, SetOptions(merge: true));
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Files synced to Cloud Vault!'), backgroundColor: Colors.green),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Media backup failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isBackingUp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DATA VAULT & BACKUP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Secure Cloud Backup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: ListTile(
              leading: const Icon(Icons.contacts, color: Colors.blueAccent),
              title: const Text('Backup Contacts'),
              subtitle: const Text('Sync your entire address book to Firestore.'),
              trailing: _isBackingUp ? const CircularProgressIndicator() : const Icon(Icons.cloud_upload),
              onTap: _isBackingUp ? null : _backupContacts,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orangeAccent),
              title: const Text('Media & Documents Vault'),
              subtitle: const Text('Securely upload photos and files to your private vault.'),
              trailing: _isBackingUp ? const CircularProgressIndicator() : const Icon(Icons.upload_file),
              onTap: _isBackingUp ? null : _backupMedia,
            ),
          ),
          const SizedBox(height: 32),
          const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SwitchListTile(
            secondary: const Icon(Icons.sync_alt, color: Colors.greenAccent),
            title: const Text('Automated Cloud Sync'),
            subtitle: const Text('Periodically back up contacts and new files in the background (Every 24h).'),
            value: _autoSyncEnabled,
            onChanged: _toggleAutoSync,
          ),
        ],
      ),
    );
  }
}
