// lib/features/shorts/presentation/widgets/report_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/short_models.dart';
import '../../data/shorts_repository.dart';

/// Bottom sheet to report incorrect / outdated content. Returns true if submitted.
Future<bool> showReportSheet(BuildContext context, String shortId) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(shortId: shortId),
  );
  return ok == true;
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.shortId});
  final String shortId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _reason;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(shortsRepositoryProvider).report(widget.shortId, _reason!, note: _note.text);
      if (!mounted) return;
      AppSnack.success(context, 'धन्यवाद! हम इसकी जाँच करेंगे।');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(context, apiErrorMessage(e, fallback: 'रिपोर्ट नहीं भेजी जा सकी। कृपया दोबारा कोशिश करें।'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reasons + note scroll; the submit button stays pinned so it is always reachable.
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('गलत या पुरानी जानकारी बताएं', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in kReportReasons.entries)
                    Semantics(
                      selected: _reason == e.key,
                      inMutuallyExclusiveGroup: true,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        minTileHeight: 48,
                        title: Text(e.value),
                        selected: _reason == e.key,
                        trailing: Icon(
                          _reason == e.key ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: _reason == e.key ? AppColors.primary : null,
                        ),
                        onTap: _busy ? null : () => setState(() => _reason = e.key),
                      ),
                    ),
                  TextField(
                    controller: _note,
                    maxLength: 500,
                    maxLines: 2,
                    enabled: !_busy,
                    decoration: const InputDecoration(hintText: 'विवरण (वैकल्पिक)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _reason == null || _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('रिपोर्ट भेजें'),
            ),
          ),
        ],
      ),
    );
  }
}
