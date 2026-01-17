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

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString('shelf_items');
    if (itemsJson != null) {
      final List<dynamic> itemsList = jsonDecode(itemsJson);
      setState(() {
        _items = itemsList.map((json) => Item.fromJson(json)).toList();
      });
      _filterItems();
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString('shelf_items', itemsJson);
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
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
              setState(() {
                _items.add(Item(name: name, quantity: quantity));
              });
              _filterItems();
              _saveItems();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _filteredItems[index].quantity = (_filteredItems[index].quantity + delta).clamp(0, 999999);
    });
    _saveItems();
  }

  void _updateQuantityFromText(int index, String value) {
    final newQuantity = int.tryParse(value) ?? _filteredItems[index].quantity;
    setState(() {
      _filteredItems[index].quantity = newQuantity.clamp(0, 999999);
    });
    _saveItems();
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _items.remove(item);
              });
              _filterItems();
              _saveItems();
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
      body: Column(
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
            child: _filteredItems.isEmpty
                ? Center(
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
                                    onPressed: () => _updateQuantity(index, -1),
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
                                      onChanged: (value) => _updateQuantityFromText(index, value),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    iconSize: 32,
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xff00a68a)),
                                    onPressed: () => _updateQuantity(index, 1),
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
        ],
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: const Center(
        child: Text('Account settings and information will go here.'),
      ),
    );
  }
}