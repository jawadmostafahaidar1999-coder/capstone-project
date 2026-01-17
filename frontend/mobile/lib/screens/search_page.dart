import 'dart:async';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../widgets/app_images.dart';
import 'product_details_page.dart';
import 'vendor_profile_page.dart';

class SearchPage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const SearchPage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final ProductService _productService;

  final _controller = TextEditingController();
  Timer? _debounce;
  String? _effectiveQuery;

  bool _loading = false;
  bool _hasSearched = false;
  String? _error;

  List<Product> _products = [];
  List<Vendor> _vendors = [];

  @override
  void initState() {
    super.initState();
    _productService = ProductService(widget.apiClient);

    // ✅ Load latest products/vendors when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search();
    });
  }

  Future<void> _search() async {
    final q = _controller.text.trim();

    if (q.isEmpty) {
      setState(() {
        _hasSearched = false;
        _effectiveQuery = null;
        _products = [];
        _vendors = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _hasSearched = true;
      _loading = true;
      _error = null;
      _effectiveQuery = null;
    });

    try {
      final attempts = _buildFallbackQueries(q);

      List<Product> foundProducts = [];
      List<Vendor> foundVendors = [];
      String? used;

      for (final attempt in attempts) {
        // 1) products (your backend already supports search)
        final prodRes = await _productService.getProducts(
          page: 1,
          perPage: 15,
          search: attempt,
          sort: 'newest',
        );

        // 2) vendors (if your /vendors is public use auth:false, otherwise auth:true)
        final vendorsJson = await widget.apiClient.get('/vendors', auth: true);
        final vendorList = _extractList(vendorsJson);

        final allVendors = vendorList
            .whereType<Map>()
            .map((e) => Vendor.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        // “loose” match vendors using attempt (not only exact contains)
        final a = _norm(attempt);
        final vFiltered = allVendors.where((v) {
          final name = _norm(v.storeName);
          if (name.contains(a)) return true;
          // small typo tolerance (shorten attempt)
          if (a.length >= 4 && name.contains(a.substring(0, a.length - 1))) {
            return true;
          }
          return false;
        }).toList();

        if (prodRes.data.isNotEmpty || vFiltered.isNotEmpty) {
          foundProducts = prodRes.data;
          foundVendors = vFiltered;
          used = attempt;
          break;
        }
      }

      // If still nothing: show “popular” fallback instead of empty
      if (foundProducts.isEmpty && foundVendors.isEmpty) {
        final prodRes = await _productService.getProducts(
          page: 1,
          perPage: 10,
          search: null,
          sort: 'newest',
        );

        final vendorsJson = await widget.apiClient.get('/vendors', auth: true);
        final vendorList = _extractList(vendorsJson);

        final allVendors = vendorList
            .whereType<Map>()
            .map((e) => Vendor.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        foundProducts = prodRes.data;
        foundVendors = allVendors.take(8).toList();
        used = null; // means fallback “popular”
      }

      if (!mounted) return;
      setState(() {
        _products = foundProducts;
        _vendors = foundVendors;
        _effectiveQuery = used; // if null -> popular fallback
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // supports:
  // - { success, data: [] }
  // - { success, data: { items: [] } }
  // - { success, items: [] }
  List<dynamic> _extractList(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return data['items'] as List;
    }
    if (json['items'] is List) return json['items'] as List;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: _onChanged, // ✅ auto-search while typing
              decoration: InputDecoration(
                hintText: 'Search food or stores...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            if (_hasSearched && !_loading && _error == null) ...[
              const SizedBox(height: 8),
              Text(
                _effectiveQuery == null
                    ? 'No close matches — showing popular results'
                    : 'Showing results for: "$_effectiveQuery"',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            Expanded(
              child: !_hasSearched
                  ? const Center(child: Text('Type something to search…'))
                  : ListView(
                      children: [
                        _sectionTitle('Vendors'),
                        if (_loading)
                          const SizedBox(
                            height: 0,
                          ) // (optional) keep layout clean
                        else if (_vendors.isEmpty)
                          const Text('No vendors found')
                        else
                          ..._vendors.map(
                            (v) => ListTile(
                              leading: _vendorLeading(v),
                              title: Text(v.storeName),
                              subtitle: Text('Status: ${v.status}'),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => VendorProfilePage(
                                      apiClient: widget.apiClient,
                                      authService: widget.authService,
                                      vendor: v,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 12),

                        _sectionTitle('Products'),
                        if (_loading)
                          const SizedBox(height: 0)
                        else if (_products.isEmpty)
                          const Text('No products found')
                        else
                          ..._products.map(
                            (p) => ListTile(
                              leading: _productLeading(p),
                              title: Text(p.name),
                              subtitle: Text(
                                p.description ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(p.price.toStringAsFixed(2)),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailsPage(
                                      product: p,
                                      apiClient: widget.apiClient,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _norm(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  List<String> _buildFallbackQueries(String q) {
    final n = _norm(q);
    final out = <String>[n];

    // split words
    final words = n.split(' ').where((w) => w.length >= 3).toList();
    for (final w in words) {
      if (!out.contains(w)) out.add(w);
    }

    // progressively shorten (typo tolerance)
    // (limit to a few attempts so we don’t spam requests)
    if (n.length >= 5) {
      out.add(n.substring(0, n.length - 1));
    }
    if (n.length >= 6) {
      out.add(n.substring(0, n.length - 2));
    }
    if (n.length >= 4) {
      out.add(n.substring(0, 4)); // “burg”
    }

    // unique
    return out.toSet().toList();
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        t,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _vendorLeading(Vendor v) {
    final letter = v.storeName.isNotEmpty ? v.storeName[0].toUpperCase() : '?';
    return AppNetAvatar(
      apiClient: widget.apiClient,
      pathOrUrl: v.image,
      radius: 20,
      fallbackLetter: letter,
      fallbackIcon: Icons.storefront,
    );
  }

  Widget _productLeading(Product p) {
    return AppNetImage(
      apiClient: widget.apiClient,
      pathOrUrl: p.image,
      width: 48,
      height: 48,
      borderRadius: BorderRadius.circular(8),
      fallbackIcon: Icons.fastfood,
      memCacheWidth: 160,
      memCacheHeight: 160,
    );
  }
}
