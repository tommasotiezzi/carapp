import 'package:flutter/material.dart';

import '../../features/search/data/catalog.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme/tokens.dart';
import 'italian_capitals.dart';

/// "Scegli il capoluogo più vicino a te": a searchable list of the 106
/// capitals, no network. Returns the province code.
Future<String?> showCapitalPicker(BuildContext context, {String? selected}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CapitalPicker(selected: selected),
    );

class _CapitalPicker extends StatefulWidget {
  const _CapitalPicker({this.selected});

  final String? selected;

  @override
  State<_CapitalPicker> createState() => _CapitalPickerState();
}

class _CapitalPickerState extends State<_CapitalPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final q = Catalog.normalize(_query);
    final shown = ItalianCapitals.all
        .where((c) => q.isEmpty || Catalog.normalize(c.name).contains(q) || c.code.toLowerCase() == q)
        .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t.capitalSearch),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final c = shown[i];
                final selected = c.code == widget.selected;
                return ListTile(
                  title: Text(c.name),
                  trailing: selected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : Text(c.code, style: Theme.of(context).textTheme.bodySmall),
                  onTap: () => Navigator.pop(context, c.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
