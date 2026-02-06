import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const MyApp());

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
    const ChartsPage(),
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
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Charts'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
      ),
    );
  }
}

// ====================== DATA MODELS ======================
class HistoryEntry {
  final DateTime timestamp;
  final int oldQuantity;
  final int newQuantity;

  HistoryEntry({
    required this.timestamp,
    required this.oldQuantity,
    required this.newQuantity,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        timestamp: DateTime.parse(json['timestamp']),
        oldQuantity: json['oldQuantity'],
        newQuantity: json['newQuantity'],
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'oldQuantity': oldQuantity,
        'newQuantity': newQuantity,
      };
}

class Item {
  String name;
  int quantity;
  List<HistoryEntry> history;

  Item({
    required this.name,
    required this.quantity,
    List<HistoryEntry>? history,
  }) : history = history ?? [];

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        name: json['name'],
        quantity: json['quantity'],
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'history': history.map((e) => e.toJson()).toList(),
      };
}

// ====================== HOME PAGE ======================
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
        loadedItems = decoded.map((j) => Item.fromJson(j)).toList();
      } catch (_) {}
    }
    setState(() => _items = loadedItems);
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
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final qty = int.tryParse(quantityController.text.trim()) ?? 1;
              setState(() => _items.add(Item(name: name, quantity: qty)));
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
    final item = _filteredItems[index];
    final old = item.quantity;
    final neu = (old + delta).clamp(0, 999999);
    if (old != neu) {
      item.history.add(HistoryEntry(timestamp: DateTime.now(), oldQuantity: old, newQuantity: neu));
    }
    setState(() => item.quantity = neu);
    await _saveItems();
  }

  Future<void> _updateQuantityFromText(int index, String value) async {
    final item = _filteredItems[index];
    final old = item.quantity;
    final neu = int.tryParse(value) ?? old;
    final clamped = neu.clamp(0, 999999);
    if (old != clamped) {
      item.history.add(HistoryEntry(timestamp: DateTime.now(), oldQuantity: old, newQuantity: clamped));
    }
    setState(() => item.quantity = clamped);
    await _saveItems();
  }

  void _deleteItem(int index) {
    final item = _filteredItems[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Remove "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _items.remove(item));
              _filterItems();
              await _saveItems();
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xfff7554d))),
          ),
        ],
      ),
    );
  }

  // ================= HISTORY CHART (per item) =================
  Widget _buildHistoryChart(Item item) {
    final sorted = List<HistoryEntry>.from(item.history)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (sorted.isEmpty) return const SizedBox.shrink();

    final spots = List.generate(
      sorted.length,
      (i) => FlSpot(i.toDouble(), sorted[i].newQuantity.toDouble()),
    );

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= sorted.length) return const Text('');
                final d = sorted[idx].timestamp;
                return Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xff00a68a),
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: const Color(0xff00a68a).withOpacity(0.1)),
          ),
        ],
        minY: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shelf'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addItem),
        ],
      ),
      body: FutureBuilder(
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
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                        : null,
                  ),
                ),
              ),
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Total items: ${_items.length}')),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadItems,
                  child: _filteredItems.isEmpty
                      ? const Center(child: Text('No items', style: TextStyle(color: Color(0xff8c95a2))))
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
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                                subtitle: const Text('Tap to adjust'),
                                trailing: Text(
                                  item.quantity.toString(),
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: item.quantity == 0 ? const Color(0xffffc235) : const Color(0xff00a68a)),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Color(0xffffc235), size: 32), onPressed: () => _updateQuantity(index, -1)),
                                        SizedBox(
                                          width: 80,
                                          child: TextField(
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            controller: TextEditingController(text: item.quantity.toString()),
                                            onChanged: (v) => _updateQuantityFromText(index, v),
                                          ),
                                        ),
                                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Color(0xff00a68a), size: 32), onPressed: () => _updateQuantity(index, 1)),
                                        const SizedBox(width: 32),
                                        IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xfff7554d), size: 32), onPressed: () => _deleteItem(index)),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Quantity History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                            Text('${item.history.length} changes', style: const TextStyle(color: Color(0xff8c95a2))),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (item.history.isEmpty)
                                          const Text('No changes yet – adjust quantity to start tracking', style: TextStyle(color: Color(0xff8c95a2)))
                                        else
                                          SizedBox(height: 220, child: _buildHistoryChart(item)),
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

// ====================== CHARTS PAGE ======================
class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});
  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  List<Item> _items = [];
  String _currentPlan = 'free';
  late SharedPreferences _prefs;
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadItems();
    setState(() => _currentPlan = _prefs.getString('subscription_plan') ?? 'free');
  }

  Future<void> _loadItems() async {
    final String? json = _prefs.getString('shelf_items');
    List<Item> loaded = [];
    if (json != null) {
      try {
        loaded = (jsonDecode(json) as List).map((j) => Item.fromJson(j)).toList();
      } catch (_) {}
    }
    setState(() => _items = loaded);
  }

  int _totalSold(Item i) => i.history.fold(0, (sum, e) => sum + (e.oldQuantity > e.newQuantity ? e.oldQuantity - e.newQuantity : 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadItems)]),
      body: FutureBuilder(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());

          if (_currentPlan == 'free') {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 90, color: Color(0xff8c95a2)),
                  const SizedBox(height: 24),
                  const Text('Premium Feature', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Upgrade to unlock charts\nand unlimited shelf items', textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Go to Account → Plans'))),
                    child: const Text('Upgrade Now'),
                  ),
                ],
              ),
            );
          }

          final withHistory = _items.where((i) => i.history.isNotEmpty).toList();
          if (withHistory.isEmpty) {
            return const Center(child: Text('Start changing quantities to see analytics'));
          }

          final popular = List<Item>.from(withHistory)..sort((a, b) => _totalSold(b).compareTo(_totalSold(a)));
          final top = popular.take(8).toList();

          return RefreshIndicator(
            onRefresh: _loadItems,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Popular Items', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Ranked by units sold', style: TextStyle(color: Color(0xff8c95a2))),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 340,
                    child: BarChart(
                      BarChartData(
                        maxY: top.isEmpty ? 10 : top.map((e) => _totalSold(e).toDouble()).reduce((a, b) => a > b ? a : b) + 5,
                        barGroups: List.generate(top.length, (i) {
                          final sold = _totalSold(top[i]).toDouble();
                          return BarChartGroupData(
                            x: i,
                            barRods: [BarChartRodData(toY: sold, color: const Color(0xff00a68a), width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))],
                          );
                        }),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 70,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= top.length) return const Text('');
                                final name = top[idx].name;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(name.length > 10 ? '${name.substring(0, 10)}…' : name, style: const TextStyle(fontSize: 11)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                        ),
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Top Sellers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ...top.map((item) => ListTile(
                        leading: CircleAvatar(backgroundColor: const Color(0xff00a68a).withOpacity(0.1), child: Text(item.name[0].toUpperCase())),
                        title: Text(item.name),
                        subtitle: Text('${item.history.length} changes • ${_totalSold(item)} units sold'),
                        trailing: Text('${_totalSold(item)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff00a68a))),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ====================== ACCOUNT PAGE ======================
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? _shopName, _phone, _email;
  String _currentPlan = 'free';
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
      _currentPlan = _prefs.getString('subscription_plan') ?? 'free';
    });
  }

  Future<void> _saveField(String key, String value) async => await _prefs.setString(key, value.trim());

  void _editShopName() { /* same as before */ }
  void _editPhone() { /* same as before */ }
  void _editEmail() { /* same as before */ }
  void _clearShelf() { /* same as before */ }

  void _setPlan(String plan) async {
    setState(() => _currentPlan = plan);
    await _prefs.setString('subscription_plan', plan);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now on $plan plan! 🎉'), backgroundColor: const Color(0xff00a68a)));
  }

  Widget _buildPlanCard({
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required List<String> features,
    required bool isCurrent,
    required String buttonText,
    required VoidCallback onTap,
    required Color color,
    bool isPopular = false,
  }) {
    return Card(
      elevation: isCurrent ? 8 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: isPopular ? Border.all(color: const Color(0xff00a68a), width: 3) : null,
        ),
        child: Column(
          children: [
            if (isPopular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xff00a68a), borderRadius: BorderRadius.circular(30)),
                child: const Text('MOST POPULAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: const TextStyle(color: Color(0xff8c95a2))),
            const SizedBox(height: 16),
            Text(price, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
            Text(period, style: const TextStyle(color: Color(0xff8c95a2), fontSize: 16)),
            const SizedBox(height: 24),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [const Icon(Icons.check_circle, color: Color(0xff00a68a), size: 20), const SizedBox(width: 12), Expanded(child: Text(f))]),
                )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isCurrent ? Colors.grey[400] : color, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: isCurrent ? null : onTap,
                child: Text(buttonText, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
            if (isCurrent) const Text('Active ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
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
            // Profile header (same as before)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(color: const Color(0xff00a68a).withOpacity(0.1)),
              child: Column(
                children: [
                  CircleAvatar(radius: 60, backgroundColor: const Color(0xff00a68a), child: const Icon(Icons.store_mall_directory, size: 80, color: Color(0xfff8f8f7))),
                  const SizedBox(height: 16),
                  Text(_shopName ?? 'My Shelf Shop', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(_email ?? 'No email', style: const TextStyle(fontSize: 16, color: Color(0xff8c95a2))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Editable fields (same as before – omitted for brevity, copy from your original)
            ListTile(leading: const Icon(Icons.store, color: Color(0xff00a68a)), title: const Text('Shop Name'), subtitle: Text(_shopName ?? 'Not set'), trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editShopName)),
            const Divider(),
            ListTile(leading: const Icon(Icons.phone, color: Color(0xff00a68a)), title: const Text('Phone'), subtitle: Text(_phone ?? 'Not set'), trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editPhone)),
            const Divider(),
            ListTile(leading: const Icon(Icons.email, color: Color(0xff00a68a)), title: const Text('Email'), subtitle: Text(_email ?? 'Not set'), trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editEmail)),
            const SizedBox(height: 32),
            // Clear shelf
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xfff7554d)), onPressed: _clearShelf, child: const Text('Clear All Shelf Items'))),
            ),
            const SizedBox(height: 40),

            // =============== PLANS SECTION ===============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plans', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Unlock charts, unlimited items & more', style: TextStyle(color: Color(0xff8c95a2))),
                  const SizedBox(height: 24),
                  _buildPlanCard(
                    title: 'Free',
                    subtitle: 'Starter',
                    price: 'GHC 0',
                    period: 'forever',
                    features: ['Up to 50 items', 'Basic tracking', 'No charts'],
                    isCurrent: _currentPlan == 'free',
                    buttonText: _currentPlan == 'free' ? 'Current' : 'Switch',
                    onTap: () => _setPlan('free'),
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    title: 'Monthly',
                    subtitle: 'Most popular',
                    price: 'GHC 20',
                    period: 'per month',
                    features: ['Unlimited items', 'Full history & charts', 'Analytics', 'Cloud backup (soon)'],
                    isCurrent: _currentPlan == 'monthly',
                    buttonText: _currentPlan == 'monthly' ? 'Current' : 'Subscribe',
                    onTap: () => _setPlan('monthly'),
                    color: const Color(0xff00a68a),
                    isPopular: true,
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    title: 'Yearly',
                    subtitle: 'Best value',
                    price: 'GHC 200',
                    period: 'per year (save GHC 40)',
                    features: ['Everything in Monthly', 'Priority support'],
                    isCurrent: _currentPlan == 'yearly',
                    buttonText: _currentPlan == 'yearly' ? 'Current' : 'Subscribe',
                    onTap: () => _setPlan('yearly'),
                    color: const Color(0xffffc235),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}