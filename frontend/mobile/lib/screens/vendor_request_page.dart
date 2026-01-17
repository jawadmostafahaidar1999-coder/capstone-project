import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/vendor_service.dart';
import '../models/vendor.dart';
import '../utils/image_upload_helper.dart';

class VendorRequestPage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const VendorRequestPage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<VendorRequestPage> createState() => _VendorRequestPageState();
}

class _VendorRequestPageState extends State<VendorRequestPage> {
  final _formKey = GlobalKey<FormState>();

  final _storeNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imageController = TextEditingController(); // will hold uploaded path

  String? _selectedArea;
  bool _submitting = false;

  late final VendorService _vendorService;

  final List<String> _areas = const [
    'Beirut',
    'Hadath',
    'Khalde',
    'Chweifat',
    'Mount Lebanon',
    'Hazmieh',
    'Hamra',
  ];

  // ---- Image picking + uploading (ADDED) ----
  Uint8List? _pickedImageBytes;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _vendorService = VendorService(widget.apiClient);
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() => _uploadingImage = true);

      final up = await ImageUploadHelper.pickAndUpload(
        apiClient: widget.apiClient,
        folder: 'vendors',
        auth: true,
        imageQuality: 75,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (up == null) return;

      setState(() {
        _pickedImageBytes = up.bytes;
        _imageController.text = up.path;
      });

      _snack('Image uploaded ✅');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please choose a location')));
      return;
    }

    // if upload is still running, block submit
    if (_uploadingImage) {
      _snack('Please wait until image upload finishes...');
      return;
    }

    setState(() => _submitting = true);

    try {
      final Vendor? vendor = await _vendorService.createVendor(
        storeName: _storeNameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _selectedArea ?? '',
        image: _imageController.text.trim().isEmpty
            ? null
            : _imageController.text.trim(),
      );

      // Refresh user (/me) so vendorStatus becomes "pending"
      await widget.authService.refreshCurrentUser();

      if (!mounted) return;

      if (vendor != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vendor request sent. Your request is pending admin approval.',
            ),
          ),
        );
        Navigator.of(context).pop(true); // tell previous page it worked
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send vendor request')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request to become vendor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Store / kitchen name *',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Location'),
                value: _selectedArea,
                items: _areas
                    .map(
                      (area) =>
                          DropdownMenuItem(value: area, child: Text(area)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedArea = value);
                },
                validator: (v) => v == null ? 'Please choose a location' : null,
              ),

              // --- REPLACED: Image URL text field -> Pick Image button (ONLY CHANGE IN UI) ---
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: (_submitting || _uploadingImage)
                    ? null
                    : _pickAndUploadImage,
                icon: _uploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library),
                label: Text(
                  _imageController.text.trim().isNotEmpty
                      ? 'Change image'
                      : 'Pick image (optional)',
                ),
              ),
              if (_pickedImageBytes != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pickedImageBytes!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_submitting ? 'Sending...' : 'Submit request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
