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
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xff00a68a)),
            borderRadius: BorderRadius.circular(8),
          ),
          labelStyle: const TextStyle(color: Color(0xff8c95a2)),
          suffixIconColor: const Color(0xff8c95a2),
        ),
      ),
      home: const MainScreen(),
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
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: const Color(0xff8c95a2),
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

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'],
      quantity: json['quantity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
    };
  }
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
        _filteredItems = _items;
      });
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = jsonEncode(_items.map((item) => item.toJson()).toList());
    await prefs.setString('shelf_items', itemsJson);
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) => item.name.toLowerCase().contains(query)).toList();
    });
  }

  void _addItem() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
                autofocus: true,
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
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
                final quantityStr = quantityController.text.trim();
                if (name.isNotEmpty && quantityStr.isNotEmpty) {
                  final quantity = int.tryParse(quantityStr) ?? 1;
                  setState(() {
                    _items.add(Item(name: name, quantity: quantity));
                    _filteredItems = _items;
                  });
                  _saveItems();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _updateQuantity(int filteredIndex, int delta) {
    setState(() {
      _filteredItems[filteredIndex].quantity = (_filteredItems[filteredIndex].quantity + delta).clamp(0, 999999);
    });
    _saveItems();
  }

  void _updateQuantityFromText(int filteredIndex, String value) {
    final newQuantity = int.tryParse(value) ?? _filteredItems[filteredIndex].quantity;
    setState(() {
      _filteredItems[filteredIndex].quantity = newQuantity.clamp(0, 999999);
    });
    _saveItems();
  }

  void _deleteItem(int filteredIndex) {
    final itemToRemove = _filteredItems[filteredIndex];
    setState(() {
      _items.remove(itemToRemove);
      _filteredItems.removeAt(filteredIndex);
    });
    _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addItem,
            tooltip: 'Add Item',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Items',
                suffixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _filteredItems.isEmpty
                ? const Center(
                    child: Text(
                      'No items yet. Add some!',
                      style: TextStyle(color: Color(0xff8c95a2)),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final quantityController = TextEditingController(text: item.quantity.toString());

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          leading: const Icon(Icons.shelf_ladder, color: Color(0xff00a68a)),
                          title: Text(
                            '${item.name} - ${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Tap to edit'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xffffc235)),
                                    onPressed: () => _updateQuantity(index, -1),
                                    tooltip: 'Decrease',
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: TextField(
                                      controller: quantityController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      onSubmitted: (value) => _updateQuantityFromText(index, value),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xff00a68a)),
                                    onPressed: () => _updateQuantity(index, 1),
                                    tooltip: 'Increase',
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xfff7554d)),
                                    onPressed: () => _deleteItem(index),
                                    tooltip: 'Delete',
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
        child: Text('Account settings and info will go here.'),
      ),
    );
  }
}