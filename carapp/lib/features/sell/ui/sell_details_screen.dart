import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/geo/capital_picker.dart';
import '../../../core/geo/italian_capitals.dart';
import '../../../core/l10n/vehicle_labels.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/thousands_formatter.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../feed/data/feed_filters.dart';
import '../../onboarding/data/catalog_repository.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../../search/data/catalog.dart';
import '../../search/data/query_parser.dart';
import '../data/sell_draft.dart';
import '../data/sell_repository.dart';
import '../state/sell_controller.dart';
import 'sell_labels.dart';

export '../../../core/utils/thousands_formatter.dart';

/// Contact data and dealer membership of the seller (one request each).
final sellerProfileProvider = FutureProvider.autoDispose<SellerProfile>(
  (ref) => ref.watch(sellRepositoryProvider).sellerProfile(),
);

/// Private sellers declare 18+ (or a parent's consent) once.
final sellerAgeConsentProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(sellRepositoryProvider).hasSellerAgeConsent(),
);

/// An online listing being edited ("Modifica annuncio"): the same form,
/// without media and age tick, saved through [onSave] ([newPhone]: the
/// WhatsApp number to save in the profile, when it changed).
class ListingEdit {
  const ListingEdit({
    required this.listingId,
    required this.categoryId,
    required this.details,
    required this.onSave,
  });

  final String listingId;
  final String categoryId;
  final SellDetails details;
  final Future<void> Function(SellDetails details, {String? newPhone}) onSave;
}

/// `/sell/shots/details` (screen 4): the listing data while the video is
/// made and uploaded; "Pubblica annuncio" waits for it if needed. With
/// [edit], the data of an online listing ("Salva modifiche").
class SellDetailsScreen extends ConsumerStatefulWidget {
  const SellDetailsScreen({super.key, this.edit});

  final ListingEdit? edit;

  @override
  ConsumerState<SellDetailsScreen> createState() => _SellDetailsScreenState();
}

class _SellDetailsScreenState extends ConsumerState<SellDetailsScreen> {
  late SellDetails _d;
  late final String _categoryId;
  late final _year = TextEditingController();
  late final _km = TextEditingController();
  late final _price = TextEditingController();
  late final _version = TextEditingController();
  late final _power = TextEditingController();
  late final _owners = TextEditingController();
  late final _color = TextEditingController();
  late final _displacement = TextEditingController();
  late final _description = TextEditingController();
  late final _city = TextEditingController();
  late final _phone = TextEditingController();

  bool _more = false;
  bool _showErrors = false;
  bool _sellerAge = false;
  bool _publishing = false;
  bool _prefilled = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    final draft = edit == null ? ref.read(sellControllerProvider).draft : null;
    _d = edit?.details ?? draft?.details ?? SellDetails.empty;
    _categoryId = edit?.categoryId ?? draft?.categoryId ?? 'car';
    String n(int? v, {bool thousands = false}) =>
        v == null ? '' : (thousands ? ThousandsFormatter.format(v) : '$v');
    _year.text = n(_d.year);
    _km.text = n(_d.mileageKm, thousands: true);
    _price.text = _d.priceCents == null ? '' : ThousandsFormatter.format(_d.priceCents! ~/ 100);
    _version.text = _d.version ?? '';
    _power.text = n(_d.powerKw);
    _owners.text = n(_d.ownersCount);
    _color.text = _d.color ?? '';
    _displacement.text = n((_d.attributes['displacement_cc'] as num?)?.toInt());
    _description.text = _d.description ?? '';
    _city.text = _d.city ?? '';
    _phone.text = _d.phone ?? '';
    _more = _d.transmission != null || _d.powerKw != null || _d.euroClass != null;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final c in [
      _year,
      _km,
      _price,
      _version,
      _power,
      _owners,
      _color,
      _displacement,
      _description,
      _city,
      _phone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Every change is kept in the draft (saved on the phone shortly after).
  void _update(SellDetails Function(SellDetails d) change) {
    setState(() => _d = change(_d));
    if (widget.edit != null) return; // saved only on "Salva modifiche"
    final controller = ref.read(sellControllerProvider.notifier);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () => controller.updateDetails(_d));
  }

  void _prefill(SellerProfile p) {
    if (_prefilled) return;
    _prefilled = true;
    final home = widget.edit == null ? ref.read(homeProvinceProvider) : null;
    if (_d.province == null && home != null) {
      _d = _d.copyWith(province: home);
      if (_city.text.isEmpty) {
        _city.text = ItalianCapitals.byCode[home]?.name ?? '';
        _d = _d.copyWith(city: _city.text);
      }
    }
    if (_city.text.isEmpty && (p.city ?? '').isNotEmpty) {
      _city.text = p.city!;
      _d = _d.copyWith(city: p.city);
    }
    if (_phone.text.isEmpty && (p.phone ?? '').isNotEmpty) {
      _phone.text = p.phone!;
      _d = _d.copyWith(phone: p.phone);
    }
  }

  int get _maxYear => DateTime.now().year + 1;

  bool get _yearValid => _d.year != null && _d.year! >= 1950 && _d.year! <= _maxYear;

  bool _phoneValid(String text) => RegExp(r'^\+?[\d\s]{8,16}$').hasMatch(text.trim());

  /// The WhatsApp number to save in the profile: private seller, WhatsApp
  /// on, and a number that is new or not public yet.
  String? _newPhone(SellerProfile? profile) {
    final phoneNeeded = profile?.dealerId == null && _d.whatsapp;
    return phoneNeeded && (_phone.text.trim() != (profile?.phone ?? '') || !(profile?.whatsappPublic ?? false))
        ? _phone.text.trim()
        : null;
  }

  Future<void> _saveEdit(SellerProfile? profile) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final phoneNeeded = profile?.dealerId == null && _d.whatsapp;
    if (!_d.isComplete || !_yearValid || (phoneNeeded && !_phoneValid(_phone.text))) {
      setState(() => _showErrors = true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.detailsFixFields)));
      return;
    }
    setState(() => _publishing = true);
    try {
      await widget.edit!.onSave(_d, newPhone: _newPhone(profile));
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.editListingSaved)));
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _publishing = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.myListingError)));
    }
  }

  Future<void> _publish(SellerProfile? profile, bool needsAgeTick) async {
    final t = AppLocalizations.of(context);
    final controller = ref.read(sellControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    _saveTimer?.cancel();
    controller.updateDetails(_d);

    final private = profile?.dealerId == null;
    final phoneNeeded = private && _d.whatsapp;
    final valid =
        _d.isComplete &&
        _yearValid &&
        (!phoneNeeded || _phoneValid(_phone.text)) &&
        (!needsAgeTick || _sellerAge);
    if (!valid) {
      setState(() => _showErrors = true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.detailsFixFields)));
      return;
    }

    setState(() => _publishing = true);
    try {
      final newPhone = _newPhone(profile);
      final id = await controller.publish(
        dealerId: profile?.dealerId,
        newPhone: newPhone,
        recordSellerAge: needsAgeTick,
      );
      if (!mounted) return;
      context.go(AppRoutes.sellDonePath(id));
    } on PublishException catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(switch (e.failure) {
              PublishFailure.incomplete => t.publishErrorIncomplete,
              PublishFailure.missingMedia => t.publishErrorMedia,
              PublishFailure.network => t.publishErrorNetwork,
              _ => t.publishError,
            }),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final editing = widget.edit != null;
    final s = ref.watch(sellControllerProvider);
    // No draft: just published (this page is leaving), or discarded.
    if (!editing && s.draft == null) return const Scaffold(backgroundColor: AppColors.surface);
    final profile = ref.watch(sellerProfileProvider).value;
    if (profile != null) _prefill(profile);
    final private = profile?.dealerId == null;
    final needsAgeTick = !editing && private && ref.watch(sellerAgeConsentProvider).value == false;
    final catalog = ref.watch(catalogProvider).value;
    final makes = ref.watch(makesProvider(_categoryId)).value ?? const <Make>[];
    final makeName = makes.where((m) => m.id == _d.makeId).firstOrNull?.name;
    final modelName = catalog?.modelById[_d.modelId]?.name;
    String? required(bool ok) => _showErrors && !ok ? t.detailsRequired : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: _publishing
              ? null
              : () => context.canPop()
                  ? context.pop()
                  : context.go(editing ? AppRoutes.profile : AppRoutes.sellShots),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
          children: [
            Text(editing ? t.editListingTitle : t.detailsTitle, style: text.headlineSmall),
            const SizedBox(height: AppSpacing.s),
            if (editing)
              Text(t.editListingNote, style: text.bodySmall)
            else
              _MediaProgress(state: s, onRetry: () => ref.read(sellControllerProvider.notifier).startMedia()),
            const SizedBox(height: AppSpacing.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PickerField(
                    label: t.detailsMake,
                    value: makeName,
                    error: required(_d.makeId != null),
                    onTap: () async {
                      final picked = await _pick(
                        context,
                        hint: t.detailsSearchMake,
                        options: [for (final m in makes) (m.id, m.name)],
                      );
                      if (picked != null && picked != _d.makeId) {
                        _update((d) => d.copyWith(makeId: picked, modelId: null));
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: _PickerField(
                    label: t.detailsModel,
                    value: modelName,
                    error: required(_d.modelId != null),
                    onTap: () async {
                      if (_d.makeId == null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(t.detailsChooseMakeFirst)));
                        return;
                      }
                      final models = (catalog ?? Catalog.empty).models.where((m) => m.makeId == _d.makeId);
                      final picked = await _pick(
                        context,
                        hint: t.detailsSearchModel,
                        options: [for (final m in models) (m.id, m.name)],
                      );
                      if (picked != null) _update((d) => d.copyWith(modelId: picked));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _NumberField(
                    label: t.detailsYear,
                    controller: _year,
                    maxLength: 4,
                    error: _showErrors && !_yearValid
                        ? (_d.year == null ? t.detailsRequired : t.detailsInvalidYear(_maxYear))
                        : null,
                    onChanged: (v) => _update((d) => d.copyWith(year: int.tryParse(v))),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: _NumberField(
                    label: t.detailsKm,
                    controller: _km,
                    thousands: true,
                    error: required(_d.mileageKm != null),
                    onChanged: (v) => _update((d) => d.copyWith(mileageKm: ThousandsFormatter.parse(v))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            _Label(t.detailsFuel, error: required(_d.fuelType != null)),
            _Chips(
              options: [for (final f in FeedFilters.fuelOptions) (f, t.fuelLabel(f))],
              selected: _d.fuelType,
              onSelected: (v) => _update((d) => d.copyWith(fuelType: v)),
            ),
            const SizedBox(height: AppSpacing.m),
            OutlinedButton(
              onPressed: () => setState(() => _more = !_more),
              child: Text(_more ? t.detailsLess : t.detailsMore, textAlign: TextAlign.center),
            ),
            if (_more) ..._moreFields(t),
            const SizedBox(height: AppSpacing.l),
            _Label(t.detailsPrice),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsFormatter()],
              style: text.headlineSmall,
              decoration: InputDecoration(
                prefixText: '€ ',
                prefixStyle: text.headlineSmall,
                errorText: required(_d.priceCents != null),
              ),
              onChanged: (v) {
                final euros = ThousandsFormatter.parse(v);
                _update((d) => d.copyWith(priceCents: euros == null ? null : euros * 100));
              },
            ),
            const SizedBox(height: AppSpacing.l),
            _Label(t.detailsDescription),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 8,
              maxLength: 3000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: t.detailsDescriptionHint, counterText: ''),
              onChanged: (v) => _update((d) => d.copyWith(description: v)),
            ),
            const SizedBox(height: AppSpacing.l),
            _Label(t.detailsWhere),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _city,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: t.detailsCity,
                      errorText: required((_d.city ?? '').trim().isNotEmpty),
                    ),
                    onChanged: (v) {
                      // A province capital fills the province too.
                      final code = QueryParser.provinceNames.entries
                          .where((e) => e.value.toLowerCase() == v.trim().toLowerCase())
                          .firstOrNull
                          ?.key;
                      _update((d) => d.copyWith(city: v, province: code ?? d.province));
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  flex: 2,
                  child: _PickerField(
                    label: t.detailsProvince,
                    value: _d.province,
                    error: required((_d.province ?? '').isNotEmpty),
                    onTap: () async {
                      final picked = await showCapitalPicker(context, selected: _d.province);
                      if (picked == null) return;
                      // An empty city becomes the capital's name.
                      if (_city.text.trim().isEmpty) _city.text = ItalianCapitals.byCode[picked]?.name ?? '';
                      _update((d) => d.copyWith(province: picked, city: _city.text));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            Material(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.m),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.detailsWhatsapp, style: text.titleSmall),
                      subtitle: Text(private ? t.detailsWhatsappHint : t.detailsWhatsappDealer),
                      value: _d.whatsapp,
                      onChanged: (v) => _update((d) => d.copyWith(whatsapp: v)),
                    ),
                    if (_d.whatsapp && private)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: t.detailsPhone,
                            hintText: '+39 333 123 4567',
                            errorText: _showErrors && !_phoneValid(_phone.text)
                                ? t.detailsInvalidPhone
                                : null,
                          ),
                          onChanged: (v) => _update((d) => d.copyWith(phone: v)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (needsAgeTick) ...[
              const SizedBox(height: AppSpacing.m),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _sellerAge,
                isError: _showErrors && !_sellerAge,
                title: Text(t.detailsSellerAge, style: text.bodyMedium),
                onChanged: (v) => setState(() => _sellerAge = v ?? false),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s, AppSpacing.page, AppSpacing.m),
          child: FilledButton(
            onPressed: _publishing || profile == null
                ? null
                : () => editing ? _saveEdit(profile) : _publish(profile, needsAgeTick),
            child: _publishing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(editing ? t.editListingSaving : t.detailsPublishing),
                    ],
                  )
                : Text(editing ? t.editListingSave : t.detailsPublish),
          ),
        ),
      ),
    );
  }

  List<Widget> _moreFields(AppLocalizations t) {
    final car = _categoryId != 'motorcycle';
    final cv = (_d.powerKw ?? 0) > 0 ? (_d.powerKw! * 1.35962).round() : null;
    return [
      const SizedBox(height: AppSpacing.l),
      TextField(
        controller: _version,
        decoration: InputDecoration(labelText: t.detailsVersion, hintText: t.detailsVersionHint),
        onChanged: (v) => _update((d) => d.copyWith(version: v)),
      ),
      const SizedBox(height: AppSpacing.l),
      _Label(t.detailsGearbox),
      _Chips(
        options: [for (final g in FeedFilters.transmissionOptions) (g, t.transmissionLabel(g))],
        selected: _d.transmission,
        onSelected: (v) => _update((d) => d.copyWith(transmission: v)),
      ),
      const SizedBox(height: AppSpacing.m),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _NumberField(
              label: t.detailsPower,
              controller: _power,
              maxLength: 4,
              helper: cv == null ? null : t.detailsPowerCv(cv),
              onChanged: (v) => _update((d) => d.copyWith(powerKw: int.tryParse(v))),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: _NumberField(
              label: t.detailsOwners,
              controller: _owners,
              maxLength: 2,
              onChanged: (v) => _update((d) => d.copyWith(ownersCount: int.tryParse(v))),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.m),
      _Label(t.detailsEuro),
      _Chips(
        options: [for (var e = 1; e <= 6; e++) ('$e', 'Euro $e')],
        selected: _d.euroClass?.toString(),
        onSelected: (v) => _update((d) => d.copyWith(euroClass: v == null ? null : int.parse(v))),
      ),
      const SizedBox(height: AppSpacing.m),
      TextField(
        controller: _color,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: t.detailsColor),
        onChanged: (v) => _update((d) => d.copyWith(color: v)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(t.detailsServiceHistory),
        value: _d.hasServiceHistory ?? false,
        onChanged: (v) => _update((d) => d.copyWith(hasServiceHistory: v)),
      ),
      if (car) ...[
        _Label(t.detailsBodyType),
        _Chips(
          options: [
            for (final b in const [
              'city_car',
              'hatchback',
              'sedan',
              'station_wagon',
              'suv',
              'coupe',
              'convertible',
              'minivan',
              'van',
              'pickup',
            ])
              (b, t.bodyTypeLabel(b)),
          ],
          selected: _d.attributes['body_type'] as String?,
          onSelected: (v) => _update((d) => d.copyWith(attributes: {...d.attributes, 'body_type': v})),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.detailsNovice),
          value: (_d.attributes['novice_ok'] as bool?) ?? false,
          onChanged: (v) => _update((d) => d.copyWith(attributes: {...d.attributes, 'novice_ok': v})),
        ),
      ] else ...[
        _Label(t.detailsMotoType),
        _Chips(
          options: [
            for (final m in const [
              'naked',
              'sport',
              'touring',
              'adventure',
              'enduro',
              'cross',
              'custom',
              'scooter',
              'motard',
            ])
              (m, t.motoTypeLabel(m)),
          ],
          selected: _d.attributes['moto_type'] as String?,
          onSelected: (v) => _update((d) => d.copyWith(attributes: {...d.attributes, 'moto_type': v})),
        ),
        const SizedBox(height: AppSpacing.m),
        _NumberField(
          label: t.detailsDisplacement,
          controller: _displacement,
          maxLength: 4,
          onChanged: (v) =>
              _update((d) => d.copyWith(attributes: {...d.attributes, 'displacement_cc': int.tryParse(v)})),
        ),
        const SizedBox(height: AppSpacing.m),
        _Label(t.detailsLicense),
        _Chips(
          options: const [('AM', 'AM'), ('A1', 'A1'), ('A2', 'A2'), ('A', 'A')],
          selected: _d.attributes['license_class'] as String?,
          onSelected: (v) => _update((d) => d.copyWith(attributes: {...d.attributes, 'license_class': v})),
        ),
      ],
    ];
  }
}

/// A searchable list in a bottom sheet. Returns the chosen id.
Future<String?> _pick(
  BuildContext context, {
  required String hint,
  required List<(String, String)> options,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _PickerSheet(hint: hint, options: options),
);

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.hint, required this.options});

  final String hint;
  final List<(String, String)> options;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = Catalog.normalize(_query);
    final shown = widget.options.where((o) => q.isEmpty || Catalog.normalize(o.$2).contains(q)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: widget.hint),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                itemCount: shown.length,
                itemBuilder: (context, i) =>
                    ListTile(title: Text(shown[i].$2), onTap: () => Navigator.pop(context, shown[i].$1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaProgress extends StatelessWidget {
  const _MediaProgress({required this.state, required this.onRetry});

  final SellState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final failed = state.phase == MediaPhase.failed;
    final ready = state.phase == MediaPhase.ready;
    final label = failed
        ? t.detailsFailed
        : ready
        ? t.detailsReady
        : t.detailsPreparing((state.progress * 100).round());

    return InkWell(
      onTap: failed ? onRetry : null,
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ready ? 1 : state.progress,
                minHeight: 4,
                color: failed ? AppColors.danger : AppColors.primary,
                backgroundColor: AppColors.border,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(label, style: text.bodySmall?.copyWith(color: failed ? AppColors.danger : null)),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.error});

  final String text;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Text(text, style: style),
          if (error != null) ...[
            const SizedBox(width: AppSpacing.s),
            Text(error!, style: style?.copyWith(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.options, required this.selected, required this.onSelected});

  final List<(String, String)> options;
  final String? selected;

  /// Tapping the selected chip clears it (null).
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.s,
    runSpacing: AppSpacing.s,
    children: [
      for (final (value, label) in options)
        ChoiceChip(
          label: Text(label),
          selected: selected == value,
          onSelected: (on) => onSelected(on ? value : null),
        ),
    ],
  );
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.value, required this.onTap, this.error});

  final String label;
  final String? value;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        // Label always on top: with an empty value it would otherwise sit
        // on "Scegli" (two texts in the same spot).
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(
          value ?? t.detailsChoose,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: value == null ? const TextStyle(color: AppColors.inkMuted) : null,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.maxLength,
    this.thousands = false,
    this.error,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final bool thousands;
  final String? error;
  final String? helper;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [
      if (thousands) const ThousandsFormatter() else FilteringTextInputFormatter.digitsOnly,
      if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
    ],
    decoration: InputDecoration(labelText: label, errorText: error, helperText: helper),
    onChanged: onChanged,
  );
}
