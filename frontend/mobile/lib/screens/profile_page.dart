// lib/screens/profile_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/api_client.dart' show ApiClient, ApiException;
import '../services/vendor_service.dart';
import '../models/app_user.dart';
import '../models/vendor.dart';
import 'vendor_profile_page.dart';
import 'vendor_request_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const ProfilePage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final VendorService _vendorService;

  Vendor? _vendor;
  bool _loadingVendor = true;
  String? _vendorError;

  Uint8List? _pickedAvatarBytes;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _vendorService = VendorService(widget.apiClient);
    _loadVendor();
  }

  Future<void> _loadVendor() async {
    setState(() {
      _loadingVendor = true;
      _vendorError = null;
    });

    try {
      final v = await _vendorService.getMyVendor();
      if (!mounted) return;
      setState(() {
        _vendor = v;
        _loadingVendor = false;
      });
    } on ApiException catch (e) {
      // if your VendorService throws 404 when no vendor, treat it as "no vendor"
      if (!mounted) return;
      setState(() {
        _vendor = null;
        _vendorError = (e.statusCode == 404) ? null : 'Failed to load vendor';
        _loadingVendor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vendorError = 'Failed to load vendor info';
        _loadingVendor = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _pickedAvatarBytes = bytes; // instant preview
      _uploadingAvatar = true;
    });

    final ok = await widget.authService.uploadAndSetProfileImage(
      bytes: bytes,
      filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
    );

    await widget.authService.refreshCurrentUser();

    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Profile image updated' : 'Upload failed')),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final ok = await widget.authService.updateProfile(
      name: nameController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile updated' : 'Failed to update profile'),
      ),
    );

    setState(() {});
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final error = await widget.authService.changePassword(
      currentPassword: currentController.text,
      newPassword: newController.text,
      newPasswordConfirmation: confirmController.text,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error == null ? 'Password changed' : error)),
    );
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          apiClient: widget.apiClient,
          authService: widget.authService,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = widget.authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.authService.refreshCurrentUser();
          await _loadVendor();
          if (mounted) setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(user),
            const SizedBox(height: 16),
            _buildAccountSection(),
            const SizedBox(height: 24),
            _buildVendorSection(user),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppUser user) {
    final avatarUrl = widget.apiClient.resolveImageUrl(user.image);

    final ImageProvider? provider = _pickedAvatarBytes != null
        ? MemoryImage(_pickedAvatarBytes!)
        : (avatarUrl != null ? NetworkImage(avatarUrl) : null);

    return Row(
      children: [
        GestureDetector(
          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundImage: provider,
                child: provider == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 22),
                      )
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: _uploadingAvatar
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(user.email),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit profile'),
            onTap: _showEditProfileDialog,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change password'),
            onTap: _showChangePasswordDialog,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildVendorSection(AppUser user) {
    final bool isVendor = user.isVendor;
    final String? vendorStatus = user.vendorStatus;

    if (_loadingVendor) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vendorError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vendor', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(_vendorError!),
          TextButton(onPressed: _loadVendor, child: const Text('Retry')),
        ],
      );
    }

    if (isVendor) {
      final vendor = _vendor;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vendor', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: Text(vendor?.storeName ?? 'My store'),
              subtitle: Text(
                'Status: ${vendor?.status ?? vendorStatus ?? 'approved'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VendorProfilePage(
                      apiClient: widget.apiClient,
                      authService: widget.authService,
                      ownerView: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    if (vendorStatus == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vendor', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Your vendor request is pending admin approval.'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_top),
            label: const Text('Request pending'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vendor', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Turn your kitchen into a store and start selling food.'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => VendorRequestPage(
                  apiClient: widget.apiClient,
                  authService: widget.authService,
                ),
              ),
            );

            if (result == true) {
              await widget.authService.refreshCurrentUser();
              await _loadVendor();
              if (!mounted) return;
              setState(() {});
            }
          },
          icon: const Icon(Icons.storefront),
          label: const Text('Become a vendor'),
        ),
      ],
    );
  }
}
