// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const MainScreen();
        }
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        throw 'Please fill in all fields';
      }

      if (!_isLogin) {
        final confirm = _confirmPasswordController.text;
        if (password != confirm) throw 'Passwords do not match';
      }

      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Create default profile for new user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({'shop_name': 'My Shelf Shop'}, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Authentication error';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2, size: 100, color: Theme.of(context).primaryColor),
              const SizedBox(height: 24),
              const Text('Shelf App', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_isLogin ? 'Welcome back' : 'Create an account', style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 32),
              _loading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _authenticate,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text(_isLogin ? 'Login' : 'Sign Up'),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "Don't have an account? Sign up" : 'Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
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
  final String id;
  final String name;
  int quantity;

  Item({required this.id, required this.name, required this.quantity});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Item> _allItems = [];
  List<Item> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  CollectionReference get _itemsRef =>
      FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).collection('items');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = _allItems
        .where((item) => item.name.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    setState(() {
      _filteredItems = filtered;
    });
  }

  Future<void> _addItem() async {
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

              await _itemsRef.add({
                'name': name,
                'quantity': quantity,
              });

              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _increment(Item item) async {
    await _itemsRef.doc(item.id).update({'quantity': FieldValue.increment(1)});
  }

  Future<void> _decrement(Item item) async {
    if (item.quantity > 0) {
      await _itemsRef.doc(item.id).update({'quantity': FieldValue.increment(-1)});
    }
  }

  Future<void> _setQuantityFromText(Item item, String value) async {
    final newQuantity = int.tryParse(value);
    if (newQuantity != null) {
      final clamped = newQuantity.clamp(0, 999999);
      if (clamped != item.quantity) {
        await _itemsRef.doc(item.id).update({'quantity': clamped});
      }
    }
  }

  Future<void> _deleteItem(Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Remove "${item.name}" (Quantity: ${item.quantity}) from your shelf?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xfff7554d))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _itemsRef.doc(item.id).delete();
    }
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
                          _filterItems();
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (_allItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total items: ${_allItems.length}',
                  style: const TextStyle(color: Color(0xff8c95a2), fontSize: 14),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _itemsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty && _allItems.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                _allItems = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Item(
                    id: doc.id,
                    name: data['name'] ?? '',
                    quantity: (data['quantity'] as num?)?.toInt() ?? 0,
                  );
                }).toList();

                _filterItems();

                if (_filteredItems.isEmpty) {
                  return LayoutBuilder(
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
                                  _allItems.isEmpty
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
                  );
                }

                return ListView.builder(
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
                                  onPressed: item.quantity > 0 ? () => _decrement(item) : null,
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
                                    onChanged: (value) => _setQuantityFromText(item, value),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  iconSize: 32,
                                  icon: const Icon(Icons.add_circle_outline, color: Color(0xff00a68a)),
                                  onPressed: () => _increment(item),
                                ),
                                const SizedBox(width: 32),
                                IconButton(
                                  iconSize: 32,
                                  icon: const Icon(Icons.delete_outline, color: Color(0xfff7554d)),
                                  onPressed: () => _deleteItem(item),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
  String? _shopPhone;
  String? _shopEmail;

  late final DocumentReference _userDoc;
  
  get _itemsRef => null;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    _loadAccountInfo();
  }

  Future<void> _loadAccountInfo() async {
    final snap = await _userDoc.get();
    final data = snap.data() as Map<String, dynamic>?;
    setState(() {
      _shopName = data?['shop_name'] as String? ?? 'My Shelf Shop';
      _shopPhone = data?['shop_phone'] as String?;
      _shopEmail = data?['shop_email'] as String?;
    });
  }

  Future<void> _saveField(String key, String? value) async {
    final Map<String, dynamic> updateData = {};
    if (value == null || value.isEmpty) {
      updateData[key] = FieldValue.delete();
    } else {
      updateData[key] = value.trim();
    }
    await _userDoc.set(updateData, SetOptions(merge: true));
    await _loadAccountInfo(); // refresh UI
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
    final controller = TextEditingController(text: _shopPhone ?? '');
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
              _saveField('shop_phone', newValue.isEmpty ? null : newValue);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editEmail() {
    final controller = TextEditingController(text: _shopEmail ?? '');
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
              _saveField('shop_email', newValue.isEmpty ? null : newValue);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearShelf() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Entire Shelf?'),
        content: const Text('This will permanently delete all items from your shelf. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Shelf', style: TextStyle(color: Color(0xfff7554d))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final query = await _itemsRef.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shelf cleared successfully!'),
            backgroundColor: Color(0xff00a68a),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SingleChildScrollView(
        child: Column(
          children: [
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
                    _shopEmail ?? 'No email set',
                    style: const TextStyle(fontSize: 16, color: Color(0xff8c95a2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
              subtitle: Text(_shopPhone ?? 'Not set'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editPhone),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xff00a68a)),
              title: const Text('Email'),
              subtitle: Text(_shopEmail ?? 'Not set'),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editEmail),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xfff7554d)),
              title: const Text('Logout'),
              onTap: _logout,
            ),
            const SizedBox(height: 32),
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