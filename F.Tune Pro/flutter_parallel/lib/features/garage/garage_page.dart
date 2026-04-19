import 'dart:ui';
import 'package:flutter/material.dart';

import '../../app/ftune_models.dart';
import '../../app/ftune_ui.dart';
import '../create/domain/tune_models.dart';
import '../dashboard/widgets/bento_glass_container.dart';

// ─── PI class helpers (mirroring dashboard logic) ─────────────────────────────
String _garageClassLabel(int pi) {
  if (pi >= 999) return 'X';
  if (pi >= 900) return 'S2';
  if (pi >= 800) return 'S1';
  if (pi >= 700) return 'A';
  if (pi >= 600) return 'B';
  if (pi >= 500) return 'C';
  return 'D';
}

Color _garageClassColor(String cls) {
  switch (cls) {
    case 'X':  return const Color(0xFFE040FB);
    case 'S2': return const Color(0xFFE53935);
    case 'S1': return const Color(0xFFFF7043);
    case 'A':  return const Color(0xFFFFB300);
    case 'B':  return const Color(0xFF00BCD4);
    case 'C':  return const Color(0xFF4CAF50);
    default:   return const Color(0xFF9E9E9E);
  }
}

int? _parsePiNumber(String piClass) {
  final m = RegExp(r'\d+').firstMatch(piClass);
  return m != null ? int.tryParse(m.group(0)!) : null;
}

// ─── Garage PI badge widget ───────────────────────────────────────────────────
class _GaragePiBadge extends StatelessWidget {
  const _GaragePiBadge({required this.piClass});
  final String piClass;

  @override
  Widget build(BuildContext context) {
    final pi   = _parsePiNumber(piClass);
    if (pi == null) {
      return Text(piClass,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700));
    }
    final cls      = _garageClassLabel(pi);
    final clrColor = _garageClassColor(cls);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: clrColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(7),
              bottomLeft: Radius.circular(7),
            ),
          ),
          child: Text(
            cls,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: clrColor.withAlpha(28),
            border: Border(
              top: BorderSide(color: clrColor.withAlpha(160)),
              right: BorderSide(color: clrColor.withAlpha(160)),
              bottom: BorderSide(color: clrColor.withAlpha(160)),
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(7),
              bottomRight: Radius.circular(7),
            ),
          ),
          child: Text(
            '$pi',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: clrColor),
          ),
        ),
      ],
    );
  }
}

class GaragePage extends StatefulWidget {
  const GaragePage({
    super.key,
    required this.languageCode,
    required this.records,
    required this.overlayPreviewEnabled,
    required this.onBack,
    required this.onCreateNew,
    required this.onDelete,
    required this.onTogglePinned,
    required this.onImport,
    required this.onExport,
    required this.onSetOverlayTune,
    required this.onEditInCreate,
  });

  final String languageCode;
  final List<SavedTuneRecord> records;
  final bool overlayPreviewEnabled;
  final VoidCallback onBack;
  final VoidCallback onCreateNew;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onTogglePinned;
  final VoidCallback onImport;
  final Future<void> Function(List<SavedTuneRecord> records) onExport;
  final Future<void> Function(SavedTuneRecord? record) onSetOverlayTune;
  final ValueChanged<SavedTuneRecord> onEditInCreate;

  @override
  State<GaragePage> createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  bool _onlyPinned = false;
  String _sortColumn = 'date';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final copy           = _GarageCopy.forLanguage(widget.languageCode);
    final palette        = FTuneElectronPaletteData.of(context);
    final isDark         = palette.isDark;
    final border         = isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12);
    final text           = isDark ? const Color(0xFFF2F6FF) : const Color(0xFF1A1E28);
    final muted          = isDark ? const Color(0xFF8A95A8) : const Color(0xFF5E6470);
    final panelBg        = isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(172);
    final visibleRecords = _filteredRecords();
    final pinnedCount = widget.records.where((record) => record.isPinned).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeader = constraints.maxWidth < 860;
        final stackedToolbar = constraints.maxWidth < 680;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BentoGlassContainer(
              borderRadius: 26,
              padding: const EdgeInsets.all(18),
              fillOpacity: palette.isDark ? 0.16 : 0.22,
              child: compactHeader
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _garageHeroLead(copy, palette, text, muted, visibleRecords),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _garageOverviewPill(
                              icon: Icons.inventory_2_rounded,
                              label: copy.isVietnamese ? 'Hiển thị' : 'Visible',
                              value:
                                  '${visibleRecords.length}/${widget.records.length}',
                              palette: palette,
                            ),
                            _garageOverviewPill(
                              icon: Icons.push_pin_rounded,
                              label: copy.isVietnamese ? 'Đã ghim' : 'Pinned',
                              value: '$pinnedCount',
                              palette: palette,
                            ),
                            _garageOverviewPill(
                              icon: Icons.done_all_rounded,
                              label: copy.isVietnamese ? 'Đã chọn' : 'Selected',
                              value: '${_selectedIds.length}',
                              palette: palette,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _GarageHeaderButton(
                              icon: Icons.arrow_back_rounded,
                              label: copy.back,
                              accent: palette.accent,
                              border: border,
                              text: text,
                              muted: muted,
                              isDark: isDark,
                              onTap: widget.onBack,
                            ),
                            _GarageHeaderButton(
                              icon: Icons.file_download_outlined,
                              label: copy.importLabel,
                              accent: palette.accent,
                              border: border,
                              text: text,
                              muted: muted,
                              isDark: isDark,
                              onTap: widget.onImport,
                            ),
                            _GarageHeaderButton(
                              icon: Icons.file_upload_outlined,
                              label: copy.exportLabel,
                              accent: palette.accent,
                              border: border,
                              text: text,
                              muted: muted,
                              isDark: isDark,
                              onTap: visibleRecords.isEmpty
                                  ? null
                                  : () =>
                                      _exportSelectionOrVisible(visibleRecords),
                            ),
                            _GarageHeaderButton(
                              icon: Icons.add_rounded,
                              label: copy.createLabel,
                              accent: palette.accent,
                              border: border,
                              text: text,
                              muted: muted,
                              isDark: isDark,
                              filled: true,
                              onTap: widget.onCreateNew,
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _garageHeroLead(
                                copy,
                                palette,
                                text,
                                muted,
                                visibleRecords,
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: <Widget>[
                                  _garageOverviewPill(
                                    icon: Icons.inventory_2_rounded,
                                    label: copy.isVietnamese
                                        ? 'Hiển thị'
                                        : 'Visible',
                                    value:
                                        '${visibleRecords.length}/${widget.records.length}',
                                    palette: palette,
                                  ),
                                  _garageOverviewPill(
                                    icon: Icons.push_pin_rounded,
                                    label: copy.isVietnamese
                                        ? 'Đã ghim'
                                        : 'Pinned',
                                    value: '$pinnedCount',
                                    palette: palette,
                                  ),
                                  _garageOverviewPill(
                                    icon: Icons.done_all_rounded,
                                    label: copy.isVietnamese
                                        ? 'Đã chọn'
                                        : 'Selected',
                                    value: '${_selectedIds.length}',
                                    palette: palette,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 304,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _GarageHeaderButton(
                                      icon: Icons.arrow_back_rounded,
                                      label: copy.back,
                                      accent: palette.accent,
                                      border: border,
                                      text: text,
                                      muted: muted,
                                      isDark: isDark,
                                      expand: true,
                                      onTap: widget.onBack,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _GarageHeaderButton(
                                      icon: Icons.file_download_outlined,
                                      label: copy.importLabel,
                                      accent: palette.accent,
                                      border: border,
                                      text: text,
                                      muted: muted,
                                      isDark: isDark,
                                      expand: true,
                                      onTap: widget.onImport,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _GarageHeaderButton(
                                      icon: Icons.file_upload_outlined,
                                      label: copy.exportLabel,
                                      accent: palette.accent,
                                      border: border,
                                      text: text,
                                      muted: muted,
                                      isDark: isDark,
                                      expand: true,
                                      onTap: visibleRecords.isEmpty
                                          ? null
                                          : () => _exportSelectionOrVisible(
                                              visibleRecords,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _GarageHeaderButton(
                                      icon: Icons.add_rounded,
                                      label: copy.createLabel,
                                      accent: palette.accent,
                                      border: border,
                                      text: text,
                                      muted: muted,
                                      isDark: isDark,
                                      filled: true,
                                      expand: true,
                                      onTap: widget.onCreateNew,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            BentoGlassContainer(
              borderRadius: 22,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              fillOpacity: palette.isDark ? 0.16 : 0.22,
              child: stackedToolbar
                  ? Column(
                      children: <Widget>[
                        _garageSearchField(copy, text, muted, border, panelBg, palette),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _pinnedToggle(copy, palette, panelBg, border, muted),
                        ),
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(
                          child: _garageSearchField(
                            copy,
                            text,
                            muted,
                            border,
                            panelBg,
                            palette,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _pinnedToggle(copy, palette, panelBg, border, muted),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.records.isEmpty
                  ? BentoGlassContainer(
                      borderRadius: 22,
                      padding: const EdgeInsets.all(20),
                      fillOpacity: palette.isDark ? 0.16 : 0.22,
                      child: _emptyState(copy, palette, isDark, muted, text),
                    )
                  : LayoutBuilder(
                      builder: (context, listConstraints) {
                        if (listConstraints.maxWidth < 900) {
                          return _listView(
                            copy,
                            palette,
                            isDark,
                            panelBg,
                            border,
                            text,
                            muted,
                            visibleRecords,
                          );
                        }
                        return _tableView(
                          copy,
                          palette,
                          isDark,
                          panelBg,
                          border,
                          text,
                          muted,
                          visibleRecords,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _garageHeroLead(
    _GarageCopy copy,
    FTuneElectronPaletteData palette,
    Color text,
    Color muted,
    List<SavedTuneRecord> visibleRecords,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.accent.withAlpha(28),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.garage_rounded, size: 18, color: palette.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                copy.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: text,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                copy.subtitle,
                style: TextStyle(fontSize: 12, height: 1.45, color: muted),
              ),
              const SizedBox(height: 6),
              Text(
                '${visibleRecords.length} / ${widget.records.length} ${copy.tunesSuffix}',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _garageOverviewPill({
    required IconData icon,
    required String label,
    required String value,
    required FTuneElectronPaletteData palette,
  }) {
    final panelBg = palette.isDark
        ? Colors.white.withAlpha(10)
        : Colors.white.withAlpha(172);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: panelBg,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: palette.accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _garageSearchField(
    _GarageCopy copy,
    Color text,
    Color muted,
    Color border,
    Color panelBg,
    FTuneElectronPaletteData palette,
  ) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: text, fontSize: 13),
      decoration: InputDecoration(
        hintText: copy.searchHint,
        hintStyle: TextStyle(color: muted, fontSize: 12),
        prefixIcon: Icon(Icons.search_rounded, color: muted, size: 18),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.accent),
        ),
        filled: true,
        fillColor: panelBg,
      ),
    );
  }

  Widget _pinnedToggle(
    _GarageCopy copy,
    FTuneElectronPaletteData palette,
    Color panelBg,
    Color border,
    Color muted,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _onlyPinned = !_onlyPinned),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _onlyPinned ? palette.accent.withAlpha(220) : panelBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _onlyPinned ? palette.accent : border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.push_pin_rounded,
              size: 14,
              color: _onlyPinned ? Colors.white : muted,
            ),
            const SizedBox(width: 5),
            Text(
              copy.onlyPinned,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _onlyPinned ? Colors.white : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(_GarageCopy copy, FTuneElectronPaletteData palette,
      bool isDark, Color muted, Color text) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(8)
                    : Colors.black.withAlpha(4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.garage_outlined, size: 48, color: muted),
            ),
            const SizedBox(height: 16),
            Text(
              copy.emptyTitle,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 22, color: text),
            ),
            const SizedBox(height: 8),
            Text(copy.emptySubtitle,
                style: TextStyle(color: muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _tableView(_GarageCopy copy, FTuneElectronPaletteData palette,
      bool isDark, Color panelBg, Color border, Color text, Color muted,
      List<SavedTuneRecord> visibleRecords) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: BentoGlassContainer(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        fillOpacity: palette.isDark ? 0.16 : 0.22,
        child: Column(
          children: <Widget>[
            _tableHeader(copy, palette, isDark, border, text, muted),
            Divider(height: 1, color: border),
            Expanded(
              child: ListView.separated(
                itemCount: visibleRecords.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: border),
                itemBuilder: (context, index) {
                  final record = visibleRecords[index];
                  return _tableRow(copy, palette, isDark, border, text, muted, record);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortableHeader({
    required String title,
    required String columnKey,
    required int flex,
    required TextStyle style,
  }) {
    final isActive = _sortColumn == columnKey;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_sortColumn == columnKey) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumn = columnKey;
              _sortAscending = true;
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  style: style.copyWith(
                    color: isActive ? FTuneElectronPaletteData.of(context).text : style.color,
                  ),
                ),
              ),
              if (isActive) ...<Widget>[
                const SizedBox(width: 4),
                Icon(
                  _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 14,
                  color: FTuneElectronPaletteData.of(context).text,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(_GarageCopy copy, FTuneElectronPaletteData palette,
      bool isDark, Color border, Color text, Color muted) {
    final style = TextStyle(
      color: muted,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(4),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 34),
          _sortableHeader(title: copy.colName, columnKey: 'tune', flex: 3, style: style),
          _sortableHeader(title: copy.colVehicle, columnKey: 'vehicle', flex: 3, style: style),
          _sortableHeader(title: copy.colDrive, columnKey: 'drive', flex: 1, style: style),
          _sortableHeader(title: copy.colSurface, columnKey: 'surface', flex: 1, style: style),
          _sortableHeader(title: copy.colType, columnKey: 'type', flex: 1, style: style),
          _sortableHeader(title: copy.colClass, columnKey: 'pi', flex: 1, style: style),
          _sortableHeader(title: copy.colTopSpeed, columnKey: 'speed', flex: 1, style: style),
          _sortableHeader(title: copy.colDate, columnKey: 'date', flex: 1, style: style),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _tableRow(_GarageCopy copy, FTuneElectronPaletteData palette,
      bool isDark, Color border, Color text, Color muted,
      SavedTuneRecord record) {
    final selected = _selectedIds.contains(record.id);

    return InkWell(
      onTap: () => _openDetails(copy, record),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Checkbox(
                value: selected,
                onChanged: (_) => _toggleSelected(record.id),
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: <Widget>[
                  if (record.isPinned)
                     Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin_rounded, size: 14, color: palette.accent),
                    ),
                  Expanded(
                    child: Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: text),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '${record.brand} ${record.model}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: text),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(record.driveType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted)),
            ),
            Expanded(
              flex: 1,
              child: Text(record.surface,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted)),
            ),
            Expanded(
              flex: 1,
              child: Text(record.tuneType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted)),
            ),
            Expanded(
              flex: 1,
              child: _GaragePiBadge(piClass: record.piClass),
            ),
            Expanded(
              flex: 1,
              child: Text(record.topSpeedDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
            ),
            Expanded(
              flex: 1,
              child: Text(_formatDate(record.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted)),
            ),
            SizedBox(
              width: 40,
              child: _rowMenu(copy, record),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listView(_GarageCopy copy, FTuneElectronPaletteData palette,
      bool isDark, Color panelBg, Color border, Color text, Color muted,
      List<SavedTuneRecord> visibleRecords) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ListView.separated(
        itemCount: visibleRecords.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final record   = visibleRecords[index];
          final selected = _selectedIds.contains(record.id);

          return _GarageListItem(
            index: index,
            child: GestureDetector(
            onTap: () => _openDetails(copy, record),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? palette.accent.withAlpha(20)
                    : panelBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? palette.accent.withAlpha(120) : border,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Checkbox(
                    value: selected,
                    onChanged: (_) => _toggleSelected(record.id),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            if (record.isPinned)
                              Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: Icon(Icons.push_pin_rounded,
                                    size: 13, color: palette.accent),
                              ),
                            Expanded(
                              child: Text(
                                record.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: text),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _GaragePiBadge(piClass: record.piClass),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.brand} ${record.model}  •  ${record.topSpeedDisplay}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _rowMenu(copy, record),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _rowMenu(_GarageCopy copy, SavedTuneRecord record) {
    return PopupMenuButton<String>(
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'open', child: Text(copy.open)),
        PopupMenuItem<String>(value: 'edit', child: Text(copy.editInCreate)),
        if (widget.overlayPreviewEnabled)
          PopupMenuItem<String>(value: 'overlay', child: Text(copy.setOverlay)),
        PopupMenuItem<String>(
          value: 'pin',
          child: Text(record.isPinned ? copy.unpin : copy.pin),
        ),
        PopupMenuItem<String>(value: 'delete', child: Text(copy.delete)),
      ],
      onSelected: (action) async {
        switch (action) {
          case 'open':
            _openDetails(copy, record);
          case 'edit':
            widget.onEditInCreate(record);
          case 'overlay':
            await widget.onSetOverlayTune(record);
          case 'pin':
            widget.onTogglePinned(record.id);
          case 'delete':
            widget.onDelete(record.id);
        }
      },
    );
  }

  Future<void> _openDetails(_GarageCopy copy, SavedTuneRecord record) async {
    final palette = FTuneElectronPaletteData.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (dialogContext, _, __) => _GarageViewModal(
        record: record,
        copy: copy,
        palette: palette,
        onEdit: () {
          widget.onEditInCreate(record);
          Navigator.of(dialogContext).pop();
        },
        metricFormatter: _metricTile,
        sliderFormatter: _formatSlider,
        dateFormatter: _formatDate,
      ),
    );
  }

  Widget _metricTile(TuneCalcMetric metric) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              metric.label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (metric.score / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: metric.color.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(metric.color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: metric.color,
            ),
          ),
        ],
      ),
    );
  }



  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _exportSelectionOrVisible(
      List<SavedTuneRecord> visibleRecords) async {
    final selected = visibleRecords
        .where((record) => _selectedIds.contains(record.id))
        .toList();
    final payload = selected.isEmpty ? visibleRecords : selected;
    await widget.onExport(payload);
  }

  List<SavedTuneRecord> _filteredRecords() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = widget.records.where((record) {
      if (_onlyPinned && !record.isPinned) return false;
      if (query.isEmpty) return true;

      return record.title.toLowerCase().contains(query) ||
          record.brand.toLowerCase().contains(query) ||
          record.model.toLowerCase().contains(query) ||
          record.shareCode.toLowerCase().contains(query) ||
          record.piClass.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      // Pinned items always go first
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }

      int cmp = 0;
      switch (_sortColumn) {
        case 'tune':
          cmp = a.title.compareTo(b.title);
        case 'vehicle':
          cmp = '${a.brand} ${a.model}'.compareTo('${b.brand} ${b.model}');
        case 'drive':
          cmp = a.driveType.compareTo(b.driveType);
        case 'surface':
          cmp = a.surface.compareTo(b.surface);
        case 'type':
          cmp = a.tuneType.compareTo(b.tuneType);
        case 'pi':
          cmp = a.piClass.compareTo(b.piClass);
        case 'speed':
          // Sort by numeric speed if we can parse it
          double speedA = double.tryParse(a.topSpeedDisplay.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
          double speedB = double.tryParse(b.topSpeedDisplay.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
          cmp = speedA.compareTo(speedB);
        case 'date':
        default:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _formatSlider(TuneCalcSlider slider) {
    if (slider.labels != null && slider.labels!.isNotEmpty) {
      final index =
          slider.value.round().clamp(0, slider.labels!.length - 1).toInt();
      return slider.labels![index];
    }

    final fixed = slider.value.toStringAsFixed(slider.decimals);
    final cleaned = fixed
        .replaceFirst(RegExp(r'\\.0+$'), '')
        .replaceFirst(RegExp(r'(\\.\\d*[1-9])0+$'), r'$1');
    return '$cleaned${slider.suffix ?? ''}';
  }
}

class _GarageViewModal extends StatefulWidget {
  const _GarageViewModal({
    required this.record,
    required this.copy,
    required this.palette,
    required this.onEdit,
    required this.metricFormatter,
    required this.sliderFormatter,
    required this.dateFormatter,
  });

  final SavedTuneRecord record;
  final _GarageCopy copy;
  final FTuneElectronPaletteData palette;
  final VoidCallback onEdit;
  final Widget Function(TuneCalcMetric) metricFormatter;
  final String Function(TuneCalcSlider) sliderFormatter;
  final String Function(DateTime) dateFormatter;

  @override
  State<_GarageViewModal> createState() => _GarageViewModalState();
}

class _GarageViewModalState extends State<_GarageViewModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _closeWithAnimation() async {
    await _animCtrl.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final record = widget.record;
    final copy = widget.copy;
    final isDark = palette.isDark;

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: child,
          ),
        );
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              width: 860,
              height: 600,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D1117).withAlpha(210)
                    : Colors.white.withAlpha(210),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(25)
                      : Colors.black.withAlpha(12),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 30),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.directions_car_rounded,
                            color: palette.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            record.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: palette.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FTuneRoundIconButton(
                          icon: Icons.close_rounded,
                          tooltip: copy.close,
                          onTap: _closeWithAnimation,
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withAlpha(12)
                          : Colors.black.withAlpha(8)),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // ── Car identity + PI badge below name ──
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                record.brand.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: palette.muted,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                record.model,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: palette.text,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              _GaragePiBadge(piClass: record.piClass),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // ── Meta chips ──
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _chip(record.topSpeedDisplay),
                              _chip(record.driveType),
                              _chip(record.surface),
                              _chip(record.tuneType),
                              if (record.shareCode.isNotEmpty)
                                _chip(record.shareCode),
                              _chip(widget.dateFormatter(record.createdAt)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // ── Tune cards (includes gearing) ──
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: record.result.cards
                                .map((card) => _buildCard(card))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withAlpha(12)
                          : Colors.black.withAlpha(8)),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: <Widget>[
                        TextButton(
                          onPressed: _closeWithAnimation,
                          child: Text(copy.close),
                        ),
                        FilledButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: Text(copy.editInCreate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    final isDark = widget.palette.isDark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.palette.accent.withAlpha(isDark ? 18 : 12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(15)
                  : Colors.black.withAlpha(8),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.palette.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(TuneCalcCard card) {
    final palette = widget.palette;
    final isDark = palette.isDark;
    final isGearing = card.title.toLowerCase().contains('gearing');
    final gearingData = isGearing ? widget.record.result.gearing : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: isGearing ? null : 240,
          constraints: isGearing ? const BoxConstraints(minWidth: 240, maxWidth: 480) : null,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(8)
                : Colors.white.withAlpha(60),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(18)
                  : Colors.black.withAlpha(10),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 25 : 10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    card.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: palette.accent,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.tune_rounded, size: 14, color: palette.muted),
                ],
              ),
              const SizedBox(height: 10),
              for (final slider in card.sliders) _sliderProgressRow(slider),
              if (gearingData != null && gearingData.ratios.isNotEmpty)
                _compactGearingGrid(gearingData, palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactGearingGrid(
      TuneCalcGearingData gearing, FTuneElectronPaletteData palette) {
    final ratios = gearing.ratios;
    final maxKmh = gearing.scaleMaxKmh;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < ratios.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            _compactGearChip(i + 1, ratios[i], maxKmh, palette),
          ],
        ],
      ),
    );
  }

  Widget _compactGearChip(int index, TuneCalcGearRatio ratio, double maxKmh,
      FTuneElectronPaletteData palette) {
    final frac = maxKmh > 0
        ? (ratio.topSpeedKmh / maxKmh).clamp(0.0, 1.0)
        : 0.0;
    final isDark = palette.isDark;
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(6)
            : Colors.black.withAlpha(4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(12)
              : Colors.black.withAlpha(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'G$index',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                ),
              ),
              const Spacer(),
              Text(
                '${ratio.ratio.toStringAsFixed(2)}  ${ratio.topSpeedKmh.round()} km/h',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 3,
              backgroundColor: palette.accent.withAlpha(20),
              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderProgressRow(TuneCalcSlider slider) {
    final palette = widget.palette;
    final range = slider.max - slider.min;
    final frac = range > 0
        ? ((slider.value - slider.min) / range).clamp(0.0, 1.0)
        : 0.0;
    final label = widget.sliderFormatter(slider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                slider.side.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: palette.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 4,
            backgroundColor: palette.border.withAlpha(60),
            valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Garage animated list item ───────────────────────────────────────────────
class _GarageListItem extends StatefulWidget {
  const _GarageListItem({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_GarageListItem> createState() => _GarageListItemState();
}

class _GarageListItemState extends State<_GarageListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    final delay = (widget.index * 28).clamp(0, 200);
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ─── Garage header action button ─────────────────────────────────────────────
class _GarageHeaderButton extends StatefulWidget {
  const _GarageHeaderButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.isDark,
    required this.onTap,
    this.filled = false,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color border;
  final Color text;
  final Color muted;
  final bool isDark;
  final VoidCallback? onTap;
  final bool filled;
  final bool expand;

  @override
  State<_GarageHeaderButton> createState() => _GarageHeaderButtonState();
}

class _GarageHeaderButtonState extends State<_GarageHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final bg = widget.filled
        ? (disabled
            ? widget.accent.withAlpha(80)
            : (_hovered ? widget.accent.withAlpha(230) : widget.accent))
        : (_hovered
            ? (widget.isDark
                ? Colors.white.withAlpha(22)
                : Colors.black.withAlpha(12))
            : (widget.isDark
                ? Colors.white.withAlpha(10)
                : Colors.black.withAlpha(6)));
    final labelColor =
        widget.filled ? Colors.white : (disabled ? widget.muted : widget.text);
    return MouseRegion(
      cursor:
          disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: disabled ? null : (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: disabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: widget.expand ? Alignment.center : null,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: widget.filled ? Colors.transparent : widget.border,
              ),
            ),
            child: Row(
                mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: widget.expand
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
              children: <Widget>[
                Icon(widget.icon, size: 15, color: labelColor),
                const SizedBox(width: 6),
                Text(widget.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: labelColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GarageCopy {
  const _GarageCopy._({required this.isVietnamese});

  factory _GarageCopy.forLanguage(String languageCode) {
    return _GarageCopy._(
        isVietnamese: languageCode.trim().toLowerCase() == 'vi');
  }

  final bool isVietnamese;

  String get title => isVietnamese ? 'Garage' : 'Garage';
  String get subtitle => isVietnamese
      ? 'Quản lý tune theo phong cách Fluent: tìm kiếm, ghim, xuất/import và chỉnh sửa lại nhanh.'
      : 'Manage tunes with Fluent layout: search, pin, import/export, and edit quickly.';

  String get back => isVietnamese ? 'Quay lại' : 'Back';
  String get importLabel => isVietnamese ? 'Nhập file' : 'Import';
  String get exportLabel => isVietnamese ? 'Xuất file' : 'Export';
  String get createLabel => isVietnamese ? 'Tạo mới' : 'New Tune';
  String get searchHint => isVietnamese
      ? 'Tìm theo tên tune, hãng, mẫu xe, mã share...'
      : 'Search by tune, brand, model, share code...';
  String get onlyPinned =>
      isVietnamese ? 'Chỉ hiển thị đã ghim' : 'Pinned only';

  String get colName => isVietnamese ? 'TUNE' : 'TUNE';
  String get colVehicle => isVietnamese ? 'XE' : 'VEHICLE';
  String get colDrive => isVietnamese ? 'DRIVE' : 'DRIVE';
  String get colSurface => isVietnamese ? 'SURFACE' : 'SURFACE';
  String get colType => isVietnamese ? 'TYPE' : 'TYPE';
  String get colClass => isVietnamese ? 'PI' : 'PI';
  String get colTopSpeed => isVietnamese ? 'SPEED' : 'SPEED';
  String get colDate => isVietnamese ? 'LƯU' : 'SAVED';

  String get open => isVietnamese ? 'Mở chi tiết' : 'Open details';
  String get editInCreate =>
      isVietnamese ? 'Chỉnh trong Create' : 'Edit in Create';
  String get setOverlay => isVietnamese ? 'Đặt làm overlay' : 'Set as overlay';
  String get pin => isVietnamese ? 'Ghim' : 'Pin';
  String get unpin => isVietnamese ? 'Bỏ ghim' : 'Unpin';
  String get delete => isVietnamese ? 'Xóa' : 'Delete';
  String get close => isVietnamese ? 'Đóng' : 'Close';
  String get noShareCode =>
      isVietnamese ? 'Không có share code' : 'No share code';

  String get emptyTitle =>
      isVietnamese ? 'Chưa có tune nào được lưu' : 'No tunes saved yet';
  String get emptySubtitle => isVietnamese
      ? 'Lưu tune từ trang Create để xây dựng Garage của bạn.'
      : 'Save tunes from Create to start building your garage.';
  String get tunesSuffix => isVietnamese ? 'tune' : 'tunes';
}
