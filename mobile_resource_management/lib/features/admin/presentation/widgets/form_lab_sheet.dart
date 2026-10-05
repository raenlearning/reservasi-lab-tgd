import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/json_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../data/models/lab.dart';
import '../../../../data/providers/api_providers.dart';

class FormLabSheet extends ConsumerStatefulWidget {
  const FormLabSheet({super.key, this.labAwal});

  final Lab? labAwal;

  static Future<bool?> tampilkan(BuildContext context, {Lab? labAwal}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FormLabSheet(labAwal: labAwal),
    );
  }

  @override
  ConsumerState<FormLabSheet> createState() => _FormLabSheetState();
}

class _FormLabSheetState extends ConsumerState<FormLabSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _kapasitasController;
  late final TextEditingController _lokasiController;
  late final TextEditingController _fasilitasController;

  late bool _isActive;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    final awal = widget.labAwal;

    _namaController = TextEditingController(text: awal?.namaLab ?? '');
    _kapasitasController = TextEditingController(
      text: awal == null ? '' : '${awal.kapasitas}',
    );
    _lokasiController = TextEditingController(text: awal?.lokasi ?? '');
    _fasilitasController = TextEditingController(
      text: awal == null ? '' : awal.fasilitas.join(', '),
    );
    _isActive = awal?.isActive ?? true;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _kapasitasController.dispose();
    _lokasiController.dispose();
    _fasilitasController.dispose();
    super.dispose();
  }

  List<String> get _fasilitas => _fasilitasController.text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _menyimpan = true);

    try {
      final api = ref.read(labApiProvider);
      final lab = Lab(
        // `id == 0` menandai laboratorium baru — server yang menentukan ID.
        id: widget.labAwal?.id ?? 0,
        namaLab: _namaController.text.trim(),
        kapasitas: Json.asInt(_kapasitasController.text),
        lokasi: _lokasiController.text.trim().isEmpty
            ? null
            : _lokasiController.text.trim(),
        fasilitas: _fasilitas,
        isActive: _isActive,
      );

      await api.simpan(lab);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppException.from(error).userMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                AppTheme.spaceMd,
                AppTheme.spaceMd,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.labAwal == null
                          ? 'Tambah laboratorium'
                          : 'Ubah laboratorium',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerTheme.color),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLg,
                    AppTheme.spaceMd,
                    AppTheme.spaceLg,
                    AppTheme.spaceXl,
                  ),
                  children: [
                    AppTextField(
                      label: 'Nama laboratorium',
                      hint: 'Contoh: Lab Komputer 1',
                      controller: _namaController,
                      validator: Validators.namaLab,
                      prefixIcon: Icons.meeting_room_outlined,
                      enabled: !_menyimpan,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    AppTextField(
                      label: 'Kapasitas',
                      hint: 'Jumlah kursi / komputer',
                      controller: _kapasitasController,
                      validator: Validators.kapasitas,
                      prefixIcon: Icons.groups_outlined,
                      keyboardType: TextInputType.number,
                      enabled: !_menyimpan,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    AppTextField(
                      label: 'Lokasi (opsional)',
                      hint: 'Contoh: Gedung B, Lantai 1',
                      controller: _lokasiController,
                      prefixIcon: Icons.place_outlined,
                      enabled: !_menyimpan,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    AppTextField(
                      label: 'Fasilitas (opsional)',
                      hint: 'Pisahkan dengan koma',
                      helperText: 'Contoh: 40 PC, Proyektor, AC',
                      controller: _fasilitasController,
                      prefixIcon: Icons.build_outlined,
                      enabled: !_menyimpan,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    SwitchListTile(
                      value: _isActive,
                      onChanged: _menyimpan
                          ? null
                          : (value) => setState(() => _isActive = value),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Laboratorium aktif',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        _isActive
                            ? 'Muncul pada kalender dan dapat dipilih saat mengajukan.'
                            : 'Disembunyikan dari kalender dan tidak dapat dipesan.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    const InfoBanner(
                      tone: InfoBannerTone.info,
                      message:
                          'Laboratorium dengan jadwal atau pengajuan aktif '
                          'sebaiknya dinonaktifkan, bukan dihapus, agar riwayat '
                          'tetap utuh.',
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    PrimaryButton(
                      label: widget.labAwal == null
                          ? 'Simpan laboratorium'
                          : 'Perbarui laboratorium',
                      icon: Icons.save_outlined,
                      isLoading: _menyimpan,
                      onPressed: _simpan,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

