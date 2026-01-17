import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/vendor_service.dart';

class VendorProfilePage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  /// true => vendor can edit profile + manage products
  /// false => public read-only products (Option A)
  final bool ownerView;

  /// For public view, pass a vendor (recommended).
  final Vendor? vendor;

  const VendorProfilePage({
    super.key,
    required this.apiClient,
    required this.authService,
    this.ownerView = false,
    this.vendor,
  });

  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage>
    with SingleTickerProviderStateMixin {
  final _profileFormKey = GlobalKey<FormState>();

  late final VendorService _vendorService;

  late final TabController _tabController;
  int _tabIndex = 0;

  bool _loadingVendor = true;
  bool _loadingProducts = true;

  Vendor? _vendor;
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loadingCategories = false;

  String? _error;

  // Profile controllers
  final _storeNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _orderDurationController = TextEditingController();
  final _imageController =
      TextEditingController(); // stores uploaded image path

  bool _savingProfile = false;
  bool _uploadingVendorImage = false;

  final ImagePicker _picker = ImagePicker();

  // Demo categories (keep your existing approach)
  final List<Category> categoryOptions = [
    Category(id: 1, name: 'Pizza'),
    Category(id: 2, name: 'Sandwiches'),
    Category(id: 3, name: 'Desserts'),
  ];

  bool get _isOwnerView => widget.ownerView;

  @override
  void initState() {
    super.initState();

    _vendorService = VendorService(widget.apiClient);

    _tabController = TabController(length: _isOwnerView ? 2 : 1, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabIndex != _tabController.index) {
        setState(() => _tabIndex = _tabController.index);
      }
    });

    _loadAll();
    _loadCategories();
    _loadProducts(); // first call might do nothing until vendor is loaded (same as your logic)
  }

  @override
  void dispose() {
    _tabController.dispose();

    _storeNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _orderDurationController.dispose();
    _imageController.dispose();

    super.dispose();
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pop(); // go back to previous page
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);

    try {
      final res = await widget.apiClient.get(
        '/categories',
        auth: false,
        query: {'page': '1', 'per_page': '200'},
      );

      final data = res['data'];
      List<dynamic> items = [];

      // Supports both:
      // { data: [ ... ] }  OR  { data: { items: [ ... ] } }
      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        items = data['items'] as List<dynamic>;
      }

      final cats = items
          .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (e) {
      _snack('Failed to load categories: $e');
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loadingVendor = true;
      _error = null;
    });

    try {
      final Vendor v;

      if (_isOwnerView) {
        final me = await _vendorService.getMyVendor();
        if (me == null) {
          throw Exception('No vendor profile found for this account.');
        }
        v = me;
      } else {
        final passed = widget.vendor;
        if (passed == null) {
          throw Exception('Vendor is missing (open this page with a vendor).');
        }
        v = passed;
      }

      _vendor = v;

      // ✅ now v is NOT nullable, so no error:
      _storeNameController.text = v.storeName;
      _descriptionController.text = v.description ?? '';
      _addressController.text = v.address ?? '';
      _phoneController.text = v.phone ?? '';
      _orderDurationController.text = v.orderDurationMinutes == null
          ? ''
          : v.orderDurationMinutes.toString();
      _imageController.text = v.image ?? '';

      await _loadProducts();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!mounted) return;
      setState(() => _loadingVendor = false);
    }
  }

  Future<void> _loadProducts() async {
    if (_vendor == null) return;

    setState(() {
      _loadingProducts = true;
      _error = null;
    });

    try {
      final res = await widget.apiClient.get(
        '/products',
        auth: _isOwnerView, // owner uses auth, public doesn't
        query: {'vendor_id': _vendor!.id},
      );

      final data = res['data'];
      final items = (data is Map<String, dynamic>)
          ? (data['items'] as List<dynamic>? ?? [])
          : <dynamic>[];

      _products = items
          .map((e) => Product.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _pickAndUploadVendorImage() async {
    if (!_isOwnerView) return;

    try {
      setState(() => _uploadingVendorImage = true);

      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (xfile == null) return;

      final bytes = await xfile.readAsBytes();
      final filename = xfile.name.isNotEmpty
          ? xfile.name
          : 'vendor_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final path = await _uploadPickedImage(
        bytes: bytes,
        filename: filename,
        folder: 'vendors',
      );

      if (path == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload failed')));
        return;
      }

      if (!mounted) return;
      setState(() {
        _imageController.text = path; // important: store uploaded path
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingVendorImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_vendor == null) return;

    setState(() => _savingProfile = true);

    try {
      await _vendorService.updateVendorProfile(
        vendorId: _vendor!.id, // ✅ REQUIRED
        storeName: _storeNameController.text.trim(), // ✅ make title editable
        description: _descriptionController.text.trim(),
        image: _imageController.text.trim().isEmpty
            ? null
            : _imageController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        orderDurationMinutes: int.tryParse(
          _orderDurationController.text.trim(),
        ),
      );

      await _loadAll();
      _snack('Profile updated ✅');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Failed to update profile');
    } finally {
      if (!mounted) return;
      setState(() => _savingProfile = false);
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.apiClient.delete('/products/${product.id}', auth: true);
      setState(() => _products.removeWhere((p) => p.id == product.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete product: $e')));
    }
  }

  Future<String?> _uploadPickedImage({
    required Uint8List bytes,
    required String filename,
    required String folder,
  }) async {
    final up = await widget.apiClient.uploadBytes(
      '/uploads',
      bytes: bytes,
      filename: filename,
      auth: true,
      fields: {'folder': folder},
    );

    final data = up['data'];
    final path = (data is Map<String, dynamic>)
        ? data['path'] as String?
        : null;
    return (path != null && path.trim().isNotEmpty) ? path : null;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showProductForm({Product? product}) async {
    if (!_isOwnerView || _vendor == null) return;

    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final priceCtrl = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    int? selectedCategoryId = product?.category?.id;

    Uint8List? pickedBytes;
    String? pickedName;
    String? uploadedPath = product?.image;

    bool uploading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            Future<void> pickAndUpload() async {
              try {
                setLocalState(() => uploading = true);

                final xfile = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 75,
                  maxWidth: 1200,
                  maxHeight: 1200,
                );
                if (xfile == null) return;

                pickedBytes = await xfile.readAsBytes();
                pickedName = xfile.name;

                final path = await _uploadPickedImage(
                  bytes: pickedBytes!,
                  filename: pickedName!,
                  folder: 'products',
                );

                if (path != null) {
                  setLocalState(() => uploadedPath = path);
                }
              } finally {
                setLocalState(() => uploading = false);
              }
            }

            return AlertDialog(
              title: Text(product == null ? 'Add product' : 'Edit product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: selectedCategoryId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No category'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: _loadingCategories
                          ? null
                          : (v) => setLocalState(() => selectedCategoryId = v),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: uploading ? null : pickAndUpload,
                          icon: const Icon(Icons.image),
                          label: Text(
                            uploading ? 'Uploading...' : 'Pick image',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            uploadedPath ?? 'No image',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final body = <String, dynamic>{
                      'name': nameCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'price': priceCtrl.text.trim(),
                      'category_id': selectedCategoryId.toString(),
                      'image': uploadedPath,
                      'vendor_id': _vendor!.id.toString(),
                    };

                    try {
                      final res = product == null
                          ? await widget.apiClient.post(
                              '/products',
                              auth: true,
                              body: body,
                            )
                          : await widget.apiClient.put(
                              '/products/${product.id}',
                              auth: true,
                              body: body,
                            );

                      final data = res['data'];
                      final p = Product.fromJson(
                        (data as Map).cast<String, dynamic>(),
                      );

                      if (!mounted) return;

                      setState(() {
                        if (product == null) {
                          _products.insert(0, p);
                        } else {
                          final idx = _products.indexWhere((x) => x.id == p.id);
                          if (idx != -1) _products[idx] = p;
                        }
                      });

                      if (mounted) Navigator.pop(ctx);
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _niceFieldDeco(
    BuildContext context, {
    required String label,
    required IconData icon,
    String? hint,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF6F3FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF9F5FB);

    final vendor = _vendor;
    final title = _isOwnerView
        ? 'My vendor profile'
        : (vendor?.storeName ?? 'Store');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(title),
        bottom: _isOwnerView
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Products'),
                ],
              )
            : null,
        actions: [
          if (_isOwnerView)
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),

      // ✅ FAB only on Products tab
      floatingActionButton: (_isOwnerView && _tabIndex == 1 && !_loadingVendor)
          ? FloatingActionButton(
              onPressed: () => _showProductForm(),
              child: const Icon(Icons.add),
            )
          : null,

      // ✅ Option A: non-owner view shows only products
      body: _loadingVendor
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : vendor == null
          ? const Center(child: Text('Vendor not found'))
          : _isOwnerView
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(context, vendor),
                _buildProductsTab(true),
              ],
            )
          : _buildProductsTab(false),
    );
  }

  Widget _buildProfileTab(BuildContext context, Vendor vendor) {
    if (!_isOwnerView) return const SizedBox.shrink();

    final imgPath = _imageController.text.trim().isNotEmpty
        ? _imageController.text.trim()
        : vendor.image;

    final imgUrl = widget.apiClient.resolveImageUrl(imgPath);
    final initialLetter =
        (_storeNameController.text.trim().isNotEmpty
                ? _storeNameController.text.trim()
                : vendor.storeName)
            .trim()
            .isNotEmpty
        ? (_storeNameController.text.trim().isNotEmpty
                  ? _storeNameController.text.trim()
                  : vendor.storeName)
              .trim()[0]
              .toUpperCase()
        : '?';

    return Form(
      key: _profileFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.black12,
                        backgroundImage: imgUrl != null
                            ? NetworkImage(imgUrl)
                            : null,
                        child: imgUrl == null
                            ? Text(
                                initialLetter,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile photo',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.black.withOpacity(0.75),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _uploadingVendorImage
                                      ? null
                                      : _pickAndUploadVendorImage,
                                  icon: _uploadingVendorImage
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.image_outlined,
                                          size: 18,
                                        ),
                                  label: const Text('Change image'),
                                ),
                                IconButton(
                                  tooltip: 'Remove image',
                                  onPressed: () {
                                    setState(() => _imageController.text = '');
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ✅ One aligned section (bordered fields)
                  TextFormField(
                    controller: _storeNameController,
                    decoration: _niceFieldDeco(
                      context,
                      label: 'Store name *',
                      icon: Icons.storefront,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Store name is required'
                        : null,
                    onChanged: (_) =>
                        setState(() {}), // refresh avatar letter if needed
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: _niceFieldDeco(
                      context,
                      label: 'Description',
                      icon: Icons.description_outlined,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: _niceFieldDeco(
                      context,
                      label: 'Location / address',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: _niceFieldDeco(
                      context,
                      label: 'Phone number',
                      icon: Icons.phone_outlined,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _orderDurationController,
                    decoration: _niceFieldDeco(
                      context,
                      label: 'Order duration (minutes)',
                      icon: Icons.schedule_outlined,
                      hint: 'e.g. 45',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _savingProfile ? null : _saveProfile,
              child: _savingProfile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(bool ownerView) {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return const Center(child: Text('No products yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (ctx, i) {
        final p = _products[i];
        final img = widget.apiClient.resolveImageUrl(p.image);

        return Card(
          child: ListTile(
            leading: (img == null)
                ? const Icon(Icons.fastfood)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      img,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,

                      // Faster decode for small thumbnails
                      cacheWidth: 150,
                      cacheHeight: 150,

                      // Shows a spinner while loading
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 50,
                          height: 50,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },

                      // Always show a fallback instead of staying blank
                      errorBuilder: (context, error, stack) {
                        return const SizedBox(
                          width: 50,
                          height: 50,
                          child: Center(child: Icon(Icons.broken_image)),
                        );
                      },
                    ),
                  ),

            title: Text(p.name),
            subtitle: Text('\$${p.price}'),
            trailing: ownerView
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showProductForm(product: p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteProduct(p),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}
