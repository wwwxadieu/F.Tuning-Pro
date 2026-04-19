import 'package:flutter/material.dart';

import '../../app/ftune_models.dart';
import '../create/domain/tune_models.dart';

class GaragePage extends StatefulWidget {
  const GaragePage({
    super.key,
    required this.records,
    required this.onBack,
    required this.onCreateNew,
    required this.onDelete,
    required this.onTogglePinned,
  });

  final List<SavedTuneRecord> records;
  final VoidCallback onBack;
  final VoidCallback onCreateNew;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onTogglePinned;

  @override
  State<GaragePage> createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SavedTuneRecord> get _visibleRecords {
    if (_query.isEmpty) return widget.records;
    return widget.records.where((record) {
      return record.title.toLowerCase().contains(_query) ||
          record.brand.toLowerCase().contains(_query) ||
          record.model.toLowerCase().contains(_query) ||
          record.shareCode.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _roundIconButton(Icons.arrow_back_ios_new_rounded, widget.onBack),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('My Garage', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search tune, brand, model...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: widget.onCreateNew,
              icon: const Icon(Icons.add_rounded),
              label: const Text('NEW TUNE'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: widget.records.isEmpty
              ? _buildEmptyState()
              : _visibleRecords.isEmpty
                  ? _buildNoResultsState()
                  : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.12,
                  ),
                  itemCount: _visibleRecords.length,
                  itemBuilder: (context, index) {
                    final record = _visibleRecords[index];
                    return _GarageTuneCard(
                      record: record,
                      onOpen: () => _openTuneDetails(context, record),
                      onDelete: () => widget.onDelete(record.id),
                      onTogglePinned: () => widget.onTogglePinned(record.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x24FFFFFF)),
          color: const Color(0x66201527),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.garage_outlined, size: 48, color: Color(0xB7FFFFFF)),
            SizedBox(height: 14),
            Text('No saved tunes yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
              'Save a tune from Create > Calculation to build your Garage.',
              style: TextStyle(color: Color(0xB7FFFFFF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return const Center(
      child: Text(
        'No tunes match your current search.',
        style: TextStyle(fontSize: 16, color: Color(0xB7FFFFFF)),
      ),
    );
  }

  Future<void> _openTuneDetails(BuildContext context, SavedTuneRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1320),
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0x3AFFFFFF)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 740),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(record.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(record.result.subtitle, style: const TextStyle(color: Color(0xB7FFFFFF))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _chip(record.brand),
                      _chip(record.model),
                      _chip(record.result.overview.topSpeedDisplay),
                      _chip(record.shareCode.isEmpty ? 'No share code' : record.shareCode, filled: true),
                      _chip(_formatDate(record.createdAt)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: record.result.overview.metrics
                                .map((metric) => _MetricCard(metric: metric))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: record.result.cards
                                .map((card) => _SetupCard(card: card))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? Colors.transparent : const Color(0x33FFFFFF)),
        gradient: filled
            ? const LinearGradient(colors: <Color>[Color(0xFFFF5B87), Color(0xFFFF9553)])
            : const LinearGradient(colors: <Color>[Color(0x4F2E2338), Color(0x2A1B1521)]),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: filled ? const Color(0xFF1E1222) : Colors.white,
        ),
      ),
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0x5E2A1E39),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _GarageTuneCard extends StatelessWidget {
  const _GarageTuneCard({
    required this.record,
    required this.onOpen,
    required this.onDelete,
    required this.onTogglePinned,
  });

  final SavedTuneRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: record.isPinned ? const Color(0x66FF9553) : const Color(0x24FFFFFF),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              (record.isPinned ? const Color(0x66FF9553) : const Color(0x44291F37)),
              const Color(0xCC18121D),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: onTogglePinned,
                  icon: Icon(
                    record.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: record.isPinned ? const Color(0xFFFFC352) : const Color(0x88FFFFFF),
                  ),
                ),
              ],
            ),
            Text('${record.brand} ${record.model}', style: const TextStyle(color: Color(0xB7FFFFFF))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MiniChip(record.result.overview.topSpeedDisplay),
                _MiniChip(record.result.overview.tireType),
                _MiniChip(record.shareCode.isEmpty ? 'No share code' : record.shareCode),
              ],
            ),
            const Spacer(),
            const Divider(color: Color(0x24FFFFFF)),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    record.result.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xB7FFFFFF)),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0x3D24192D),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final TuneCalcMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0x45261D32),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Column(
        children: <Widget>[
          Text(metric.label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CircularProgressIndicator(
                  value: metric.score / 100,
                  strokeWidth: 6,
                  color: metric.color,
                  backgroundColor: const Color(0x22FFFFFF),
                ),
                Center(child: Text(metric.value, style: const TextStyle(fontWeight: FontWeight.w900))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.card});

  final TuneCalcCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0x3F251B31),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(card.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final slider in card.sliders) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    slider.side.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xA6FFFFFF)),
                  ),
                ),
                Text(_formatSlider(slider), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: slider.max <= slider.min
                    ? 0
                    : ((slider.value - slider.min) / (slider.max - slider.min)).clamp(0, 1).toDouble(),
                minHeight: 5,
                backgroundColor: const Color(0x1FFFFFFF),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B83)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  String _formatSlider(TuneCalcSlider slider) {
    if (slider.labels != null && slider.labels!.isNotEmpty) {
      final index = slider.value.round().clamp(0, slider.labels!.length - 1).toInt();
      return slider.labels![index];
    }
    final fixed = slider.value.toStringAsFixed(slider.decimals);
    final cleaned = fixed.replaceFirst(RegExp(r'\.0+$'), '').replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
    return '${cleaned}${slider.suffix ?? ''}';
  }
}
