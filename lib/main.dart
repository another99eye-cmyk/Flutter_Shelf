// main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf App',
      theme: ThemeData(
        primaryColor: const Color(0xff00a68a),
        scaffoldBackgroundColor: const Color(0xfff8f8f7),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xff00a68a),
          secondary: const Color(0xff8c95a2),
          error: const Color(0xfff7554d),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xff333e50)),
          bodyMedium: TextStyle(color: Color(0xff333e50)),
          labelLarge: TextStyle(color: Color(0xff333e50)),
          headlineSmall: TextStyle(color: Color(0xff333e50), fontWeight: FontWeight.bold),
        ),
        cardColor: const Color(0xfff5f4f5),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff00a68a),
            foregroundColor: const Color(0xfff8f8f7),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xff333e50)),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xff8c95a2)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xff00a68a), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: const TextStyle(color: Color(0xff8c95a2)),
          suffixIconColor: const Color(0xff8c95a2),
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const AccountPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: const Color(0xff8c95a2),
        backgroundColor: const Color(0xfff5f4f5),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
      ),
    );
  }
}

class Item {
  String name;
  int quantity;

  Item({required this.name, required this.quantity});

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        name: json['name'] as String,
        quantity: json['quantity'] as int,
      );

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity};
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Item> _items = [];
  List<Item> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  late SharedPreferences _prefs;
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _initPrefsAndLoad();
    _searchController.addListener(_filterItems);
  }

  Future<void> _initPrefsAndLoad() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final String? itemsJson = _prefs.getString('shelf_items');
    List<Item> loadedItems = [];
    if (itemsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(itemsJson);
        loadedItems = decoded.map((dynamic json) => Item.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e) {
        // Handle invalid JSON gracefully
        loadedItems = [];
      }
    }
    setState(() {
      _items = loadedItems;
    });
    _filterItems();
  }

  Future<void> _saveItems() async {
    final String itemsJson = jsonEncode(_items.map((e) => e.toJson()).toList());
    await _prefs.setString('shelf_items', itemsJson);
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredItems = _items
          .where((item) => item.name.toLowerCase().contains(query))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }

  void _addItem() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Quantity (default 1)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xff8c95a2))),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
              setState(() {
                _items.add(Item(name: name, quantity: quantity));
              });
              _filterItems();
              await _saveItems();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateQuantity(int index, int delta) async {
    setState(() {
      _filteredItems[index].quantity = (_filteredItems[index].quantity + delta).clamp(0, 999999);
    });
    await _saveItems();
  }

  Future<void> _updateQuantityFromText(int index, String value) async {
    final newQuantity = int.tryParse(value) ?? _filteredItems[index].quantity;
    setState(() {
      _filteredItems[index].quantity = newQuantity.clamp(0, 999999);
    });
    await _saveItems();
  }

  void _deleteItem(int index) {
    final item = _filteredItems[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Remove "${item.name}" (Quantity: ${item.quantity}) from your shelf?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _items.remove(item);
              });
              _filterItems();
              await _saveItems();
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xfff7554d))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shelf'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addItem,
            tooltip: 'Add Item',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search items',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterItems();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total items: ${_items.length}',
                      style: const TextStyle(color: Color(0xff8c95a2), fontSize: 14),
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadItems,
                  child: _filteredItems.isEmpty
                      ? LayoutBuilder(
                          builder: (_, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: IntrinsicHeight(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.inventory,
                                        size: 80,
                                        color: const Color(0xff8c95a2).withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _items.isEmpty
                                            ? 'Your shelf is empty.\nTap + to add items!'
                                            : 'No items match your search.',
                                        style: const TextStyle(color: Color(0xff8c95a2), fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ExpansionTile(
                                leading: const Icon(Icons.inventory, color: Color(0xff00a68a)),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                                ),
                                subtitle: const Text('Tap to adjust quantity or delete'),
                                trailing: Text(
                                  item.quantity.toString(),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: item.quantity == 0 ? const Color(0xffffc235) : const Color(0xff00a68a),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          iconSize: 32,
                                          icon: const Icon(Icons.remove_circle_outline, color: Color(0xffffc235)),
                                          onPressed: () async => await _updateQuantity(index, -1),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 80,
                                          child: TextField(
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            controller: TextEditingController(text: item.quantity.toString())
                                              ..selection = TextSelection.fromPosition(
                                                  TextPosition(offset: item.quantity.toString().length)),
                                            onChanged: (value) async => await _updateQuantityFromText(index, value),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        IconButton(
                                          iconSize: 32,
                                          icon: const Icon(Icons.add_circle_outline, color: Color(0xff00a68a)),
                                          onPressed: () async => await _updateQuantity(index, 1),
                                        ),
                                        const SizedBox(width: 32),
                                        IconButton(
                                          iconSize: 32,
                                          icon: const Icon(Icons.delete_outline, color: Color(0xfff7554d)),
                                          onPressed: () => _deleteItem(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? _shopName;
  String? _phone;
  String? _email;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadAccountInfo();
  }

  Future<void> _loadAccountInfo() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = _prefs.getString('shop_name') ?? 'My Shelf Shop';
      _phone = _prefs.getString('shop_phone');
      _email = _prefs.getString('shop_email');
    });
  }

  Future<void> _saveField(String key, String value) async {
    await _prefs.setString(key, value.trim());
  }

  void _editShopName() {
    final controller = TextEditingController(text: _shopName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Shop Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Shop Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty) {
                setState(() => _shopName = newValue);
                _saveField('shop_name', newValue);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editPhone() {
    final controller = TextEditingController(text: _phone);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newValue = controller.text;
              setState(() => _phone = newValue.isEmpty ? null : newValue);
              if (newValue.isNotEmpty) {
                _saveField('shop_phone', newValue);
              } else {
                _prefs.remove('shop_phone');
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editEmail() {
    final controller = TextEditingController(text: _email);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email Address'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newValue = controller.text.trim();
              setState(() => _email = newValue.isEmpty ? null : newValue);
              if (newValue.isNotEmpty) {
                _saveField('shop_email', newValue);
              } else {
                _prefs.remove('shop_email');
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _clearShelf() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Entire Shelf?'),
        content: const Text('This will permanently delete all items from your shelf. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _prefs.remove('shelf_items');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Shelf cleared successfully! Switch to Home and pull down to refresh.'),
                    backgroundColor: Color(0xff00a68a),
                  ),
                );
              }
            },
            child: const Text('Clear Shelf', style: TextStyle(color: Color(0xfff7554d))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: const Color(0xff00a68a).withOpacity(0.1),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xff00a68a),
                    child: const Icon(Icons.store_mall_directory, size: 80, color: Color(0xfff8f8f7)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _shopName ?? 'My Shelf Shop',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xff333e50)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _email ?? 'No email set',
                    style: const TextStyle(fontSize: 16, color: Color(0xff8c95a2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Editable Fields
            ListTile(
              leading: const Icon(Icons.store, color: Color(0xff00a68a)),
              title: const Text('Shop Name'),
              subtitle: Text(_shopName ?? 'Not set'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editShopName),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.phone, color: Color(0xff00a68a)),
              title: const Text('Phone Number'),
              subtitle: Text(_phone ?? 'Not set'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editPhone),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xff00a68a)),
              title: const Text('Email'),
              subtitle: Text(_email ?? 'Not set'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editEmail),
            ),
            const SizedBox(height: 32),
            // Clear Shelf Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff7554d),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _clearShelf,
                  child: const Text('Clear All Shelf Items', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Premium Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xff00a68a).withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.star_border_purple500_sharp, size: 60, color: Color(0xffffc235)),
                    const SizedBox(height: 16),
                    const Text(
                      'Go Premium',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff333e50)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Unlimited shelf items\n'
                      '• Cloud backup & sync\n'
                      '• Advanced analytics\n'
                      '• Priority support\n'
                      '• No ads',
                      style: TextStyle(fontSize: 16, color: Color(0xff333e50)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                      onPressed: () {
                        // Placeholder for future premium upgrade
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Premium upgrade coming soon!')),
                        );
                      },
                      child: const Text('Upgrade Now', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}