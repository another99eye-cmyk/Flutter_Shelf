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
  double price;
  List<HistoryEntry> history;

  Item({
    required this.name,
    required this.quantity,
    required this.price,
    List<HistoryEntry>? history,
  }) : history = history ?? [];

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        name: json['name'],
        quantity: json['quantity'],
        price: json['price'] as double? ?? 0.0,
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
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

  final Map<Item, int> _tempQuantities = {};
  final Map<Item, double> _tempPrices = {};
  final Map<Item, int> _snapshotQuantities = {};
  final Map<Item, TextEditingController> _qtyControllers = {};
  final Map<Item, TextEditingController> _priceControllers = {};

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
    _qtyControllers.values.forEach((c) => c.dispose());
    _priceControllers.values.forEach((c) => c.dispose());
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
    final priceController = TextEditingController(text: '0.00');
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
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price (GHC)'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
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
              final price = double.tryParse(priceController.text.trim()) ?? 0.0;
              setState(() {
                _items.add(Item(name: name, quantity: quantity, price: price));
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

  void _updateQuantity(int index, int delta) {
    final item = _filteredItems[index];
    if (_tempQuantities.containsKey(item)) {
      _tempQuantities[item] = (_tempQuantities[item]! + delta).clamp(0, 999999);
      _qtyControllers[item]!.text = _tempQuantities[item]!.toString();
      setState(() {});
    }
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
                            final displayQty = _tempQuantities.containsKey(item) ? _tempQuantities[item]! : item.quantity;
                            if (!_qtyControllers.containsKey(item)) {
                              _qtyControllers[item] = TextEditingController(text: displayQty.toString());
                            }
                            if (!_priceControllers.containsKey(item)) {
                              _priceControllers[item] = TextEditingController(text: item.price.toStringAsFixed(2));
                            }
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
                                  displayQty.toString(),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: displayQty == 0 ? const Color(0xffffc235) : const Color(0xff00a68a),
                                  ),
                                ),
                                onExpansionChanged: (expanded) async {
                                  if (expanded) {
                                    _snapshotQuantities[item] = item.quantity;
                                    _tempQuantities[item] = item.quantity;
                                    _tempPrices[item] = item.price;
                                    _qtyControllers[item]!.text = item.quantity.toString();
                                    _priceControllers[item]!.text = item.price.toStringAsFixed(2);
                                  } else {
                                    bool changed = false;
                                    final newQty = _tempQuantities[item] ?? item.quantity;
                                    if (newQty != item.quantity) {
                                      item.history.add(HistoryEntry(
                                        timestamp: DateTime.now(),
                                        oldQuantity: _snapshotQuantities[item]!,
                                        newQuantity: newQty,
                                      ));
                                      item.quantity = newQty;
                                      changed = true;
                                    }
                                    final newPrice = _tempPrices[item] ?? item.price;
                                    if (newPrice != item.price) {
                                      item.price = newPrice;
                                      changed = true;
                                    }
                                    if (changed) {
                                      await _saveItems();
                                    }
                                    _tempQuantities.remove(item);
                                    _tempPrices.remove(item);
                                    _snapshotQuantities.remove(item);
                                  }
                                  setState(() {});
                                },
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Row(
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
                                                controller: _qtyControllers[item],
                                                onChanged: (value) {
                                                  final newQuantity = int.tryParse(value) ?? item.quantity;
                                                  _tempQuantities[item] = newQuantity.clamp(0, 999999);
                                                  setState(() {});
                                                },
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
                                        const SizedBox(height: 24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text('Price (GHC): ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                            const SizedBox(width: 16),
                                            SizedBox(
                                              width: 120,
                                              child: TextField(
                                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                textAlign: TextAlign.center,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                controller: _priceControllers[item],
                                                onChanged: (value) {
                                                  final newPrice = double.tryParse(value) ?? item.price;
                                                  _tempPrices[item] = newPrice;
                                                  setState(() {});
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
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

  double _totalValue(Item i) => i.price * i.quantity;

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
          final popular = List<Item>.from(withHistory)..sort((a, b) => _totalSold(b).compareTo(_totalSold(a)));
          final topPopular = popular.take(8).toList();

          final valuable = List<Item>.from(_items.where((i) => i.price > 0 && i.quantity > 0))..sort((a, b) => _totalValue(b).compareTo(_totalValue(a)));
          final topValuable = valuable.take(8).toList();

          final totalValue = _items.fold(0.0, (sum, i) => sum + _totalValue(i));

          return RefreshIndicator(
            onRefresh: _loadItems,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Total Money Made', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('GHC ${totalValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, color: Color(0xff00a68a), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('(Current Inventory Value)', style: TextStyle(color: Color(0xff8c95a2))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Popular Items', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Ranked by units sold', style: TextStyle(color: Color(0xff8c95a2))),
                  const SizedBox(height: 24),
                  if (topPopular.isEmpty)
                    const Text('No sales data yet', style: TextStyle(color: Color(0xff8c95a2)))
                  else ...[
                    SizedBox(
                      height: 340,
                      child: BarChart(
                        BarChartData(
                          maxY: topPopular.isEmpty ? 10 : topPopular.map((e) => _totalSold(e).toDouble()).reduce((a, b) => a > b ? a : b) + 5,
                          barGroups: List.generate(topPopular.length, (i) {
                            final sold = _totalSold(topPopular[i]).toDouble();
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
                                  if (idx >= topPopular.length) return const Text('');
                                  final name = topPopular[idx].name;
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
                    ...topPopular.map((item) => ListTile(
                          leading: CircleAvatar(backgroundColor: const Color(0xff00a68a).withOpacity(0.1), child: Text(item.name[0].toUpperCase())),
                          title: Text(item.name),
                          subtitle: Text('${item.history.length} changes • ${_totalSold(item)} units sold'),
                          trailing: Text('${_totalSold(item)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff00a68a))),
                        )),
                  ],
                  const SizedBox(height: 48),
                  const Text('Most Valuable Items', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Ranked by total value (price × quantity)', style: TextStyle(color: Color(0xff8c95a2))),
                  const SizedBox(height: 24),
                  if (topValuable.isEmpty)
                    const Text('Set prices for items to see values', style: TextStyle(color: Color(0xff8c95a2)))
                  else ...[
                    SizedBox(
                      height: 340,
                      child: BarChart(
                        BarChartData(
                          maxY: topValuable.isEmpty ? 10 : topValuable.map((e) => _totalValue(e)).reduce((a, b) => a > b ? a : b) + 5,
                          barGroups: List.generate(topValuable.length, (i) {
                            final value = _totalValue(topValuable[i]);
                            return BarChartGroupData(
                              x: i,
                              barRods: [BarChartRodData(toY: value, color: const Color(0xffffc235), width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))],
                            );
                          }),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 70,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= topValuable.length) return const Text('');
                                  final name = topValuable[idx].name;
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
                    const Text('Top Valuable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ...topValuable.map((item) => ListTile(
                          leading: CircleAvatar(backgroundColor: const Color(0xffffc235).withOpacity(0.1), child: Text(item.name[0].toUpperCase())),
                          title: Text(item.name),
                          subtitle: Text('Price: GHC ${item.price.toStringAsFixed(2)} • Qty: ${item.quantity}'),
                          trailing: Text('GHC ${_totalValue(item).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xffffc235))),
                        )),
                  ],
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
  String? _shopName;
  String? _phone;
  String? _email;
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
            // Plans Section
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