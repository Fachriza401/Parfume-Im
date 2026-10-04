import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/notification_provider.dart';
import '../admin/admin_screen.dart';
import '../admin/orders_admin_screen.dart';
import '../cart/cart_screen.dart';
import '../catalog/catalog_screen.dart';
import '../orders/order_list_screen.dart';
import '../profile/profile_screen.dart';

/// Bottom-navigation shell holding the customer-facing sections plus the admin
/// panel for users with the admin role.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  Timer? _notificationTimer;

  static const List<Widget> _customerPages = <Widget>[
    CatalogScreen(),
    CartScreen(),
    OrderListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // The cart badge depends on server-side totals, so load once on entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CartProvider>().load();
      context.read<NotificationProvider>().load();
      _notificationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) context.read<NotificationProvider>().load();
      });
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<CartProvider, int>(
      (provider) => provider.summary.totalItems,
    );
    final isAdmin = context.select<AuthProvider, bool>(
      (provider) => provider.user?.isAdmin ?? false,
    );

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: isAdmin
            ? <Widget>[
                const OrdersAdminScreen(),
                AdminScreen(onOpenOrders: () => setState(() => _index = 0)),
              ]
            : _customerPages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: const Color(0xFF1A1A1A),
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: isAdmin
            ? const <Widget>[
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Pesanan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Admin',
                ),
              ]
            : <Widget>[
                const NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'Katalog',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_bag),
                  ),
                  label: 'Keranjang',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Pesanan',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
      ),
    );
  }
}
