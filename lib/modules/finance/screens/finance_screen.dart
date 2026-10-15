import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../cubit/finance_cubit.dart';
import '../models/finance_entry_model.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String _selectedFilter = 'all'; // 'all', 'income', 'expense', 'fuel', 'toll'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet & Trip Finance Tracker'),
        actions: [
          IconButton(
            tooltip: 'Refresh Ledger',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<FinanceCubit>().load(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 4,
        backgroundColor: AppTheme.orange,
        foregroundColor: Colors.white,
        onPressed: () => _openAddEntrySheet(context),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Add Entry',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
      body: PageBody(
        onRefresh: () => context.read<FinanceCubit>().load(),
        child: BlocConsumer<FinanceCubit, ResourceState<List<FinanceEntryModel>>>(
          listener: (context, state) {
            if (state.error != null) showNotice(context, state.error!);
            if (state.notice != null) showNotice(context, state.notice!);
          },
          builder: (context, state) => ResourceView<List<FinanceEntryModel>>(
            state: state,
            retry: () => context.read<FinanceCubit>().load(),
            builder: (entries) {
              final now = DateTime.now();
              final monthEntries = entries
                  .where(
                    (entry) =>
                        entry.occurredOn.year == now.year &&
                        entry.occurredOn.month == now.month,
                  )
                  .toList();

              final totalIncome = monthEntries
                  .where((e) => e.type == 'income')
                  .fold<double>(0, (sum, e) => sum + e.amount);
              final totalExpenses = monthEntries
                  .where((e) => e.type == 'expense')
                  .fold<double>(0, (sum, e) => sum + e.amount);
              final netProfit = totalIncome - totalExpenses;

              // Filtered entries list
              final filtered = entries.where((e) {
                // Type or category filter
                if (_selectedFilter == 'income' && e.type != 'income') return false;
                if (_selectedFilter == 'expense' && e.type != 'expense') return false;
                if (_selectedFilter == 'fuel' && e.category.toLowerCase() != 'fuel') return false;
                if (_selectedFilter == 'toll' && e.category.toLowerCase() != 'toll') return false;

                // Search query
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final matchCat = e.category.toLowerCase().contains(q);
                  final matchNote = e.note.toLowerCase().contains(q);
                  final matchAmount = e.amount.toString().contains(q);
                  if (!matchCat && !matchNote && !matchAmount) return false;
                }
                return true;
              }).toList();

              final money = NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹',
                decimalDigits: 0,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Finance Command Hero Card
                  _buildFinancialHero(
                    context,
                    income: totalIncome,
                    expenses: totalExpenses,
                    net: netProfit,
                    money: money,
                    monthEntriesCount: monthEntries.length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),

                  // 2. Category Quick Telemetry Chips
                  _buildCategoryTelemetryStrip(
                    monthEntries: monthEntries,
                    money: money,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),

                  // 3. Search & Filter Bar
                  _buildFilterRow(
                    isDark: isDark,
                    totalCount: entries.length,
                    incomeCount: entries.where((e) => e.type == 'income').length,
                    expenseCount: entries.where((e) => e.type == 'expense').length,
                  ),
                  const SizedBox(height: 16),

                  // 4. Ledger Entries Header
                  Row(
                    children: [
                      Text(
                        'Transaction Ledger',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${filtered.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMMM yyyy').format(now),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5. Transaction Cards Feed
                  if (filtered.isEmpty)
                    _buildEmptyState(isDark)
                  else
                    ..._groupAndRenderEntries(filtered, money, isDark),

                  const SizedBox(height: 88),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── 1. Financial Command Hero Card ────────────────────────────────────────

  Widget _buildFinancialHero(
    BuildContext context, {
    required double income,
    required double expenses,
    required double net,
    required NumberFormat money,
    required int monthEntriesCount,
    required bool isDark,
  }) {
    final isProfitable = net >= 0;
    final marginPercent = income > 0 ? (net / income * 100).clamp(-100, 100) : 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2018),
            Color(0xFF193F35),
            Color(0xFF132F27),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF6BDB9C).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 13,
                      color: isProfitable ? const Color(0xFF6BDB9C) : const Color(0xFFFFB899),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase()} BALANCE',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Profit Margin Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isProfitable
                      ? const Color(0xFF6BDB9C).withValues(alpha: 0.15)
                      : const Color(0xFFEF5350).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isProfitable
                        ? const Color(0xFF6BDB9C).withValues(alpha: 0.45)
                        : const Color(0xFFEF5350).withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  isProfitable
                      ? '+${marginPercent.toStringAsFixed(1)}% MARGIN'
                      : '${marginPercent.toStringAsFixed(1)}% DEFICIT',
                  style: TextStyle(
                    color: isProfitable ? const Color(0xFF6BDB9C) : const Color(0xFFFF8A80),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Net Balance Figure
          Text(
            'Net Operating Profit',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${net < 0 ? '-' : '+'}${money.format(net.abs())}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'this month',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dual Revenue & Expense Summary Cards
          Row(
            children: [
              // Income Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF6BDB9C).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6BDB9C).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              size: 13,
                              color: Color(0xFF6BDB9C),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Freight Income',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        money.format(income),
                        style: const TextStyle(
                          color: Color(0xFF6BDB9C),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Expense Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFFB899).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB899).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 13,
                              color: Color(0xFFFFB899),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Trip Expenses',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        money.format(expenses),
                        style: const TextStyle(
                          color: Color(0xFFFFB899),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Category Telemetry Strip ───────────────────────────────────────────

  Widget _buildCategoryTelemetryStrip({
    required List<FinanceEntryModel> monthEntries,
    required NumberFormat money,
    required bool isDark,
  }) {
    double sumCategory(String cat) => monthEntries
        .where((e) => e.category.toLowerCase() == cat.toLowerCase())
        .fold(0.0, (s, e) => s + e.amount);

    final fuelTotal = sumCategory('fuel');
    final tollTotal = sumCategory('toll');
    final maintenanceTotal = sumCategory('maintenance');
    final allowanceTotal = sumCategory('driver_allowance');

    final items = [
      ('Fuel (Diesel)', fuelTotal, Icons.local_gas_station_rounded, const Color(0xFFFF9800), 'fuel'),
      ('Toll & Fastag', tollTotal, Icons.toll_rounded, const Color(0xFF2196F3), 'toll'),
      ('Maintenance', maintenanceTotal, Icons.build_rounded, const Color(0xFF9C27B0), 'maintenance'),
      ('Driver Bata', allowanceTotal, Icons.fastfood_rounded, const Color(0xFF009688), 'driver_allowance'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final (label, total, icon, color, catKey) = item;
          final isSelected = _selectedFilter == catKey;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _selectedFilter = _selectedFilter == catKey ? 'all' : catKey;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF193F35) : const Color(0xFFEAF5EE))
                      : (isDark ? const Color(0xFF15251F) : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6BDB9C)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 14, color: color),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          money.format(total),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF193F35),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 3. Search & Filter Bar ────────────────────────────────────────────────

  Widget _buildFilterRow({
    required bool isDark,
    required int totalCount,
    required int incomeCount,
    required int expenseCount,
  }) {
    final filters = [
      ('all', 'All', totalCount),
      ('income', 'Freight Income', incomeCount),
      ('expense', 'Expenses', expenseCount),
      ('fuel', 'Fuel Only', null),
      ('toll', 'Tolls Only', null),
    ];

    return Column(
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF15251F) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07),
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by category, fuel pump, toll plaza, note...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final (key, title, count) = f;
              final isSelected = _selectedFilter == key;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  selected: isSelected,
                  showCheckmark: false,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : const Color(0xFF193F35)),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 5),
                        Text(
                          '($count)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.7)
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ],
                    ],
                  ),
                  selectedColor: const Color(0xFF193F35),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF0F4F1),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF6BDB9C).withValues(alpha: 0.5)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                  ),
                  onSelected: (_) => setState(() => _selectedFilter = key),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── 4. Grouped Transaction Cards Feed ─────────────────────────────────────

  List<Widget> _groupAndRenderEntries(
    List<FinanceEntryModel> entries,
    NumberFormat money,
    bool isDark,
  ) {
    // Sort descending by date
    final sorted = List<FinanceEntryModel>.from(entries)
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));

    // Group by Date string
    final Map<String, List<FinanceEntryModel>> grouped = {};
    for (final e in sorted) {
      final key = DateFormat('yyyy-MM-dd').format(e.occurredOn);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final widgets = <Widget>[];

    grouped.forEach((dateKey, dateEntries) {
      final date = DateTime.parse(dateKey);
      final now = DateTime.now();
      String headerLabel;
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        headerLabel = 'Today · ${DateFormat('d MMMM').format(date)}';
      } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
        headerLabel = 'Yesterday · ${DateFormat('d MMMM').format(date)}';
      } else {
        headerLabel = DateFormat('EEEE, d MMMM yyyy').format(date);
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            headerLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : Colors.black45,
              letterSpacing: 0.4,
            ),
          ),
        ),
      );

      for (final entry in dateEntries) {
        widgets.add(_buildTransactionCard(entry, money, isDark));
      }
    });

    return widgets;
  }

  Widget _buildTransactionCard(
    FinanceEntryModel entry,
    NumberFormat money,
    bool isDark,
  ) {
    final isIncome = entry.type == 'income';
    final (icon, iconColor, bgBadge) = _getCategoryVisuals(entry.category, isIncome);
    final categoryTitle = _formatCategoryTitle(entry.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15251F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Category Icon Container
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgBadge,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        categoryTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF193F35),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (isIncome ? const Color(0xFF2E7D32) : const Color(0xFFE65100))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isIncome ? 'INCOME' : 'EXPENSE',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isIncome ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (entry.note.trim().isNotEmpty) ...[
                  Text(
                    entry.note,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  DateFormat('h:mm a').format(entry.occurredOn),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Amount
          Text(
            '${isIncome ? '+' : '-'}${money.format(entry.amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isIncome
                  ? (isDark ? const Color(0xFF6BDB9C) : const Color(0xFF2E7D32))
                  : (isDark ? const Color(0xFFFFB899) : const Color(0xFFD32F2F)),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color) _getCategoryVisuals(String category, bool isIncome) {
    if (isIncome) {
      return (
        Icons.attach_money_rounded,
        const Color(0xFF2E7D32),
        const Color(0xFF2E7D32).withValues(alpha: 0.14),
      );
    }
    switch (category.toLowerCase()) {
      case 'fuel':
        return (
          Icons.local_gas_station_rounded,
          const Color(0xFFFF9800),
          const Color(0xFFFF9800).withValues(alpha: 0.14),
        );
      case 'toll':
        return (
          Icons.toll_rounded,
          const Color(0xFF2196F3),
          const Color(0xFF2196F3).withValues(alpha: 0.14),
        );
      case 'maintenance':
        return (
          Icons.build_rounded,
          const Color(0xFF9C27B0),
          const Color(0xFF9C27B0).withValues(alpha: 0.14),
        );
      case 'driver_allowance':
        return (
          Icons.fastfood_rounded,
          const Color(0xFF009688),
          const Color(0xFF009688).withValues(alpha: 0.14),
        );
      default:
        return (
          Icons.receipt_long_rounded,
          const Color(0xFF78909C),
          const Color(0xFF78909C).withValues(alpha: 0.14),
        );
    }
  }

  String _formatCategoryTitle(String cat) {
    switch (cat.toLowerCase()) {
      case 'freight':
        return 'Freight Settlement';
      case 'fuel':
        return 'Diesel / Fuel';
      case 'toll':
        return 'Highway Toll / Fastag';
      case 'maintenance':
        return 'Vehicle Maintenance';
      case 'driver_allowance':
        return 'Driver Allowance / Bata';
      default:
        return cat.isEmpty ? 'General' : '${cat[0].toUpperCase()}${cat.substring(1)}';
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15251F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 32,
              color: AppTheme.orange,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Ledger Entries Found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF193F35),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Record freight earnings, diesel receipts, toll debits, and trip expenses to keep your transport accounts organized.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _openAddEntrySheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Entry Now', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddEntrySheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<FinanceCubit>(),
        child: const _FinanceForm(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned Bottom Sheet Entry Creation Modal Form
// ─────────────────────────────────────────────────────────────────────────────

class _FinanceForm extends StatefulWidget {
  const _FinanceForm();

  @override
  State<_FinanceForm> createState() => _FinanceFormState();
}

class _FinanceFormState extends State<_FinanceForm> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  final note = TextEditingController();

  String type = 'expense';
  String category = 'fuel';
  DateTime occurredOn = DateTime.now();

  final List<double> _quickAmountPresets = const [
    500,
    1000,
    2000,
    5000,
    10000,
    25000,
  ];

  final List<(String, String, IconData)> _expenseCategories = const [
    ('fuel', 'Diesel / Fuel', Icons.local_gas_station_rounded),
    ('toll', 'Toll / Fastag', Icons.toll_rounded),
    ('maintenance', 'Maintenance', Icons.build_rounded),
    ('driver_allowance', 'Driver Bata', Icons.fastfood_rounded),
    ('other', 'Other Cost', Icons.more_horiz_rounded),
  ];

  final List<(String, String, IconData)> _incomeCategories = const [
    ('freight', 'Freight Pay', Icons.payments_rounded),
    ('advance', 'Trip Advance', Icons.account_balance_wallet_rounded),
    ('incentive', 'Bonus / Detention', Icons.stars_rounded),
    ('other', 'Other Income', Icons.more_horiz_rounded),
  ];

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final isIncome = type == 'income';
    final categories = isIncome ? _incomeCategories : _expenseCategories;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15251F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Bar
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (isIncome ? const Color(0xFF2E7D32) : AppTheme.orange).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: isIncome ? const Color(0xFF2E7D32) : AppTheme.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Finance Entry',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF193F35),
                          ),
                        ),
                        Text(
                          'Keep your trip revenue and costs accurate',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── 1. Segmented Type Selector (Income vs Expense) ────────────
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    // Expense Option
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () {
                          setState(() {
                            type = 'expense';
                            category = 'fuel';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isIncome
                                ? (isDark ? const Color(0xFF332018) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: !isIncome
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: !isIncome ? AppTheme.orange : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Fleet Expense',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: !isIncome
                                      ? AppTheme.orange
                                      : (isDark ? Colors.white54 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Income Option
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () {
                          setState(() {
                            type = 'income';
                            category = 'freight';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isIncome
                                ? (isDark ? const Color(0xFF163327) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: isIncome
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                color: isIncome ? const Color(0xFF2E7D32) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Freight Income',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isIncome
                                      ? const Color(0xFF2E7D32)
                                      : (isDark ? Colors.white54 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ─── 2. Visual Category Selector ───────────────────────────────
              Text(
                'CATEGORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white60 : const Color(0xFF193F35),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final (key, label, icon) = cat;
                  final isSelected = category == key;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => category = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isIncome ? const Color(0xFF193F35) : AppTheme.orange)
                            : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F1)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? (isIncome ? const Color(0xFF6BDB9C) : Colors.white)
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12),
                          width: isSelected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ─── 3. Amount Input with Quick Preset Chips ───────────────────
              Text(
                'AMOUNT IN RUPEES (INR)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white60 : const Color(0xFF193F35),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: amount,
                label: 'Amount in ₹',
                hint: 'e.g. 4500',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                    ? 'Enter a valid amount.'
                    : null,
              ),

              // Quick Amount Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickAmountPresets.map((val) {
                    final label = NumberFormat.compactCurrency(
                      symbol: '₹',
                      locale: 'en_IN',
                      decimalDigits: 0,
                    ).format(val);

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        label: Text('+ $label', style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          final current = double.tryParse(amount.text.trim()) ?? 0;
                          final next = current + val;
                          setState(() {
                            amount.text = next.toStringAsFixed(0);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // ─── 4. Note & Description ─────────────────────────────────────
              Text(
                'NOTES & DETAILS (OPTIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white60 : const Color(0xFF193F35),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: note,
                label: 'Description / Location / Vendor',
                hint: isIncome
                    ? 'e.g. Cochin to Bangalore FTL freight balance'
                    : 'e.g. Diesel 45L IOCL Aluva or Fastag Paliyekkara',
                maxLength: 500,
              ),
              const SizedBox(height: 20),

              // ─── Submit Button ─────────────────────────────────────────────
              BlocBuilder<FinanceCubit, ResourceState<List<FinanceEntryModel>>>(
                builder: (context, state) => AppButton(
                  label: isIncome ? 'Record Freight Revenue' : 'Record Fleet Expense',
                  icon: isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  busy: state.busy,
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    final ok = await context.read<FinanceCubit>().save(
                      FinanceEntryDraft(
                        type: type,
                        category: category,
                        amount: double.parse(amount.text.trim()),
                        occurredOn: occurredOn,
                        note: note.text.trim(),
                      ),
                    );
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
