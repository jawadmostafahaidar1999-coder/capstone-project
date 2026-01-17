import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/paginated_response.dart';
import '../services/api_client.dart';
import '../services/product_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_images.dart';
import 'product_details_page.dart';
import 'login_page.dart';
import 'vendor_profile_page.dart';
import 'cart_page.dart';
import 'orders_page.dart';
import 'wishlist_page.dart';

class PublicProductListPage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const PublicProductListPage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<PublicProductListPage> createState() => _PublicProductListPageState();
}

class _PublicProductListPageState extends State<PublicProductListPage> {
  late final ProductService _productService;

  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  PaginationMeta? _meta;
  int _page = 1;
  final int _perPage = 10;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  String _sort = 'newest'; // newest | price_asc | price_desc

  // Simple UI-only category filters (client-side based on category.name)
  final List<String> _categories = ['All', 'Meals', 'Desserts', 'Snacks'];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _productService = ProductService(widget.apiClient);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------- DATA LOADING ----------------

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _products = [];
      _meta = null;
      _page = 1;
    });

    try {
      final response = await _productService.getProducts(
        page: _page,
        perPage: _perPage,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        sort: _sort,
      );

      setState(() {
        _products = response.data;
        _meta = response.meta;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_canLoadMore || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _errorMessage = '';
    });

    try {
      final nextPage = _page + 1;
      final response = await _productService.getProducts(
        page: nextPage,
        perPage: _perPage,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        sort: _sort,
      );

      setState(() {
        _page = nextPage;
        _products.addAll(response.data);
        _meta = response.meta;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  bool get _canLoadMore {
    if (_meta == null) return false;
    return _page < _meta!.lastPage;
  }

  // ---------------- UI HELPERS ----------------

  void _onSearchSubmitted(String _) {
    _loadFirstPage();
  }

  void _onSortChanged(String? value) {
    if (value == null) return;
    setState(() {
      _sort = value;
    });
    _loadFirstPage();
  }

  void _onCategorySelected(String value) {
    setState(() {
      _selectedCategory = value;
    });
  }

  Future<void> logout() async {
    await widget.authService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          authService: widget.authService,
          apiClient: widget.apiClient,
        ),
      ),
      (route) => false,
    );
  }

  List<Product> get _visibleProducts {
    if (_selectedCategory == 'All') {
      return _products;
    }

    return _products
        .where((p) => p.category?.name == _selectedCategory)
        .toList();
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final bool isVendor = user?.isVendor ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Icon(Icons.fastfood),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Homemade Food',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text('Deliver to: Your area', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (isVendor)
            IconButton(
              icon: const Icon(Icons.storefront),
              tooltip: 'My vendor profile',
              onPressed: () {
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
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'My wishlist',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WishlistPage(
                    apiClient: widget.apiClient,
                    authService: widget.authService,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'My cart',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CartPage(
                    apiClient: widget.apiClient,
                    authService: widget.authService,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'My orders',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrdersPage(
                    apiClient: widget.apiClient,
                    authService: widget.authService,
                  ),
                ),
              );
            },
          ),
          if (user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                widget.authService.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => LoginPage(
                      apiClient: widget.apiClient,
                      authService: widget.authService,
                    ),
                  ),
                  (route) => false,
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeroSection(context),
          _buildFilters(),
          _buildCategoryChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.home, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Homemade food from local kitchens',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover home-cooked meals prepared near you.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _onSearchSubmitted,
            decoration: InputDecoration(
              hintText: 'Search dishes or vendors...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Sort by:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sort,
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(value: 'price_asc', child: Text('Price ↑')),
                  DropdownMenuItem(value: 'price_desc', child: Text('Price ↓')),
                ],
                onChanged: _onSortChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final bool selected = _selectedCategory == category;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => _onCategorySelected(category),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage, textAlign: TextAlign.center),
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(child: Text('No products found'));
    }

    final visibleProducts = _visibleProducts;

    if (visibleProducts.isEmpty) {
      return const Center(child: Text('No products for this category'));
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: visibleProducts.length + (_canLoadMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (_canLoadMore && index == visibleProducts.length) {
            return _buildLoadMoreRow();
          }

          final product = visibleProducts[index];
          return _buildProductTile(product);
        },
      ),
    );
  }

  Widget _buildProductTile(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: AppNetImage(
          apiClient: widget.apiClient,
          pathOrUrl: product.image,
          width: 56,
          height: 56,
          borderRadius: BorderRadius.circular(8),
          fallbackIcon: Icons.fastfood_rounded,
          memCacheWidth: 180,
          memCacheHeight: 180,
        ),
        title: Text(product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.category != null)
              Text(
                product.category!.name,
                style: const TextStyle(fontSize: 12),
              ),
            if (product.description != null &&
                product.description!.trim().isNotEmpty)
              Text(
                product.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Text(
          product.price.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(
                product: product,
                apiClient: widget.apiClient,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadMoreRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator()
            : OutlinedButton(
                onPressed: _loadMore,
                child: const Text('Load more'),
              ),
      ),
    );
  }
}
