import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/search/data/catalog.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme/tokens.dart';
import 'device_location.dart';
import 'italian_capitals.dart';

/// "Scegli il capoluogo più vicino a te": "Usa la mia posizione" (GPS ->
/// nearest capital) or a searchable list of the 106 capitals, no network.
/// Returns the province code.
Future<String?> showCapitalPicker(BuildContext context, {String? selected}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CapitalPicker(selected: selected),
    );

class _CapitalPicker extends ConsumerStatefulWidget {
  const _CapitalPicker({this.selected});

  final String? selected;

  @override
  ConsumerState<_CapitalPicker> createState() => _CapitalPickerState();
}

class _CapitalPickerState extends ConsumerState<_CapitalPicker> {
  String _query = '';
  bool _locating = false;
  String? _error;

  Future<void> _useMyPosition() async {
    final t = AppLocalizations.of(context);
    final locate = ref.read(nearestCapitalLocatorProvider);
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final capital = await locate();
      if (mounted) Navigator.pop(context, capital.code);
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = switch (e.failure) {
          LocationFailure.serviceOff => t.capitalLocationOff,
          LocationFailure.denied => t.capitalLocationDenied,
          LocationFailure.unavailable => t.capitalLocationError,
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _locating = false;
          _error = t.capitalLocationError;
        });
      }
    }
  }

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
          ListTile(
            leading: _locating
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: AppColors.primary),
            title: Text(
              _locating ? t.capitalLocating : t.capitalUseLocation,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            subtitle: _error == null ? null : Text(_error!, style: const TextStyle(color: AppColors.danger)),
            onTap: _locating ? null : _useMyPosition,
          ),
          const Divider(height: 1),
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
