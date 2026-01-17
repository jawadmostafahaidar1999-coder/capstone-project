import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import 'orders_page.dart';

class CartPage extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;

  const CartPage({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final CartService _cartService;
  late final OrderService _orderService;

  CartData? _cart;
  bool _loading = true;
  String? _error;
  bool _placingOrder = false;

  @override
  void initState() {
    super.initState();
    _cartService = CartService(apiClient: widget.apiClient);
    _orderService = OrderService(apiClient: widget.apiClient);
    _loadCart();
  }

  Future<void> _checkout() async {
    final cart = _cart;
    if (cart == null || cart.items.isEmpty) return;

    setState(() {
      _placingOrder = true;
      _error = null;
    });

    try {
      final order = await _orderService.checkoutFromCart();

      await _loadCart(); // cart is cleared by backend

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #${order.id} placed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to place order')));
    } finally {
      if (mounted) {
        setState(() {
          _placingOrder = false;
        });
      }
    }
  }

  Future<void> _loadCart() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cart = await _cartService.getCart();
      setState(() {
        _cart = cart;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load cart';
        _loading = false;
      });
    }
  }

  Future<void> _changeQuantity(CartItem item, int newQuantity) async {
    if (newQuantity < 1) return;

    try {
      final cart = await _cartService.updateQuantity(
        cartItemId: item.id,
        quantity: newQuantity,
      );
      setState(() {
        _cart = cart;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update quantity')),
      );
    }
  }

  Future<void> _removeItem(CartItem item) async {
    try {
      final cart = await _cartService.removeItem(item.id);
      setState(() {
        _cart = cart;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to remove item')));
    }
  }

  Future<void> _clearCart() async {
    try {
      final cart = await _cartService.clearCart();
      setState(() {
        _cart = cart;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to clear cart')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = _cart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: cart == null || cart.items.isEmpty ? null : _clearCart,
            tooltip: 'Clear cart',
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
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : cart == null || cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : RefreshIndicator(
              onRefresh: _loadCart,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        final product = item.product;

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              product.name.isNotEmpty
                                  ? product.name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(product.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Price: ${product.price.toStringAsFixed(2)}',
                              ),
                              Text(
                                'Subtotal: ${item.subtotal.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () =>
                                    _changeQuantity(item, item.quantity - 1),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () =>
                                    _changeQuantity(item, item.quantity + 1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeItem(item),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      boxShadow: const [
                        BoxShadow(blurRadius: 4, offset: Offset(0, -2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Total items: ${cart.totalQuantity}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Total price: ${cart.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: (cart.items.isEmpty || _placingOrder)
                              ? null
                              : _checkout,
                          child: Text(
                            _placingOrder ? 'Placing order...' : 'Checkout',
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
}
