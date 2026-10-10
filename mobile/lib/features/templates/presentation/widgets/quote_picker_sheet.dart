// lib/features/templates/presentation/widgets/quote_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/data/quotes_library.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import 'editor_sheet_frame.dart';

class QuotePickerSheet extends StatefulWidget {
  final Function(String quote) onSelectQuote;

  /// Currently applied quote (shown with a selection ring) and a callback to
  /// remove it. Both optional so existing callers keep working.
  final String? selectedQuote;
  final VoidCallback? onClear;

  const QuotePickerSheet({
    super.key,
    required this.onSelectQuote,
    this.selectedQuote,
    this.onClear,
  });

  @override
  State<QuotePickerSheet> createState() => _QuotePickerSheetState();
}

class _QuotePickerSheetState extends State<QuotePickerSheet> {
  static const String _all = 'सभी (All)';

  final TextEditingController _search = TextEditingController();
  String _selectedCategory = _all;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StatusQuote> get _filtered {
    final q = _query.trim().toLowerCase();
    return QuotesLibrary.all.where((quote) {
      if (_selectedCategory != _all && quote.category != _selectedCategory) return false;
      if (q.isEmpty) return true;
      return quote.textHi.toLowerCase().contains(q) ||
          (quote.textMr ?? '').toLowerCase().contains(q) ||
          (quote.textEn ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final quotes = _filtered;
    const cats = QuotesLibrary.categories;
    final selectedIdx = cats.indexOf(_selectedCategory);

    return EditorSheetFrame(
      title: 'सुविचार संग्रह',
      subtitle: 'अपनी पसंद का सुविचार चुनकर स्टेटस पर लगाएं',
      heightFactor: 0.82,
      scrollBody: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xs),
            child: AppSearchField(
              controller: _search,
              hint: 'सुविचार खोजें...',
              onChanged: (v) => setState(() => _query = v),
              onClear: () => setState(() => _query = ''),
            ),
          ),
          FilterPillRow(
            labels: cats,
            selectedIndex: selectedIdx < 0 ? 0 : selectedIdx,
            onSelected: (i) => setState(() => _selectedCategory = cats[i]),
          ),
          if (widget.selectedQuote != null && widget.onClear != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () {
                    widget.onClear!();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.format_clear_rounded, size: 20),
                  label: const Text('सुविचार हटाएं'),
                ),
              ),
            ),
          Expanded(
            child: quotes.isEmpty
                ? const EmptyState(
                    icon: Icons.format_quote_rounded,
                    title: 'कोई सुविचार नहीं मिला',
                    message: 'दूसरा शब्द या श्रेणी आज़माएं',
                    compact: true,
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.xs,
                      AppSpacing.page,
                      AppSpacing.xl + MediaQuery.of(context).padding.bottom,
                    ),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: quotes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _QuoteTile(
                      quote: quotes[index],
                      selected: quotes[index].textHi == widget.selectedQuote,
                      palette: p,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onSelectQuote(quotes[index].textHi);
                        Navigator.pop(context);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  final StatusQuote quote;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _QuoteTile({
    required this.quote,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return PressableScale(
      scale: 0.98,
      onTap: onTap,
      semanticLabel: 'सुविचार चुनें: ${quote.textHi}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? p.primarySurface : p.surfaceMuted,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: selected ? p.primary : p.border, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(quote.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quote.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 13, weight: FontWeight.w700, color: p.primary),
                  ),
                ),
                if (selected) Icon(Icons.check_circle_rounded, color: p.primary, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quote.textHi,
              style: AppText.body(size: 17, weight: FontWeight.w600, color: p.textPrimary, height: 1.5),
            ),
            if (quote.textMr != null) ...[
              const SizedBox(height: 4),
              Text(
                quote.textMr!,
                style: AppText.body(size: 14, color: p.textMuted, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
