import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/lab_schedule.dart';
import '../../../../data/providers/api_providers.dart';
import '../../../../data/services/booking_api.dart';
import '../../../calendar/providers/calendar_providers.dart';

/// Formulir input jadwal laboratorium (khusus Kepala Laboratorium).
///
/// Menampilkan peringatan bila jadwal yang akan disimpan bertabrakan dengan
/// jadwal lain atau reservasi yang sudah disetujui. Kepala Laboratorium tetap
/// dapat melanjutkan — sistem hanya mencegah kesalahan input yang tidak
/// disengaja.
class FormJadwalSheet extends ConsumerStatefulWidget {
  const FormJadwalSheet({super.key, this.jadwalAwal});

  /// Diisi bila sedang mengubah jadwal yang sudah ada.
  final LabSchedule? jadwalAwal;

  /// Menampilkan formulir sebagai bottom sheet.
  ///
  /// Mengembalikan `true` bila data berhasil disimpan.
  static Future<bool?> tampilkan(
    BuildContext context, {
    LabSchedule? jadwalAwal,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FormJadwalSheet(jadwalAwal: jadwalAwal),
    );
  }

  @override
  ConsumerState<FormJadwalSheet> createState() => _FormJadwalSheetState();
}

class _FormJadwalSheetState extends ConsumerState<FormJadwalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mataKuliahController;
  late final TextEditingController _namaDosenController;
  late final TextEditingController _catatanController;

  int? _idLab;
  late DateTime _tanggal;
  late TimeOfDay _jamMulai;
  late TimeOfDay _jamSelesai;
  late ScheduleType _tipe;

  bool _menyimpan = false;

  /// Jadwal dibuat berulang setiap 7 hari sampai [_ulangiSampai].
  ///
  /// Hanya berlaku untuk jadwal **baru** — mengubah jadwal yang sudah ada
  /// selalu satu baris, karena setiap kemunculan adalah baris tersendiri di
  /// database dan tidak ada yang menghubungkannya satu sama lain.
  bool _ulangiMingguan = false;
  DateTime? _ulangiSampai;

  @override
  void initState() {
    super.initState();
    final awal = widget.jadwalAwal;

    _mataKuliahController = TextEditingController(
      text: awal?.mataKuliah ?? '',
    );
    _namaDosenController = TextEditingController(text: awal?.namaDosen ?? '');
    _catatanController = TextEditingController(text: awal?.catatan ?? '');

    _idLab = awal?.idLab;
    _tanggal = DateTime.tryParse(awal?.tanggal ?? '') ?? DateTimeUtils.today;
    _jamMulai = _jamDari(awal?.jamMulai, const TimeOfDay(hour: 8, minute: 0));
    _jamSelesai = _jamDari(
      awal?.jamSelesai,
      const TimeOfDay(hour: 10, minute: 0),
    );
    _tipe = awal?.tipe ?? ScheduleType.reguler;
  }

  /// Membaca `'HH:mm'` tanpa melempar.
  ///
  /// `DateTimeUtils.parseTimeKey` melempar `FormatException` pada nilai kosong
  /// atau rusak. Karena dipanggil dari `initState`, satu jadwal berjam tidak
  /// sah membuat sheet "Ubah jadwal" tidak pernah terbangun sama sekali.
  static TimeOfDay _jamDari(String? nilai, TimeOfDay cadangan) {
    final menit = DateTimeUtils.minutesFromTimeKey(nilai ?? '');
    if (menit < 0 || menit >= 24 * 60) return cadangan;
    return TimeOfDay(hour: menit ~/ 60, minute: menit % 60);
  }

  @override
  void dispose() {
    _mataKuliahController.dispose();
    _namaDosenController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  String get _jamMulaiKey => DateTimeUtils.toTimeKey(_jamMulai);
  String get _jamSelesaiKey => DateTimeUtils.toTimeKey(_jamSelesai);

  int get _mulaiMenit => DateTimeUtils.minutesFromTimeKey(_jamMulaiKey);
  int get _selesaiMenit => DateTimeUtils.minutesFromTimeKey(_jamSelesaiKey);

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTimeUtils.today,
      lastDate: DateTimeUtils.today.add(
        const Duration(days: AppConfig.bookingHorizonDays * 4),
      ),
      helpText: 'Pilih tanggal jadwal',
    );
    if (hasil == null) return;
    setState(() {
      _tanggal = hasil;
      // Tanggal akhir pengulangan tidak boleh mendahului tanggal mulai.
      if (_ulangiSampai != null && _ulangiSampai!.isBefore(hasil)) {
        _ulangiSampai = hasil;
      }
    });
  }

  Future<void> _pilihJam({required bool mulai}) async {
    final hasil = await showTimePicker(
      context: context,
      initialTime: mulai ? _jamMulai : _jamSelesai,
      helpText: mulai ? 'Jam mulai' : 'Jam selesai',
    );
    if (hasil == null) return;
    setState(() {
      if (mulai) {
        _jamMulai = hasil;
      } else {
        _jamSelesai = hasil;
      }
    });
  }

  /// Bawaan tanggal akhir pengulangan: 16 kemunculan, kira-kira satu semester.
  DateTime get _tanggalAkhirDefault =>
      _tanggal.add(const Duration(days: 7 * 15));

  /// Jumlah kemunculan mingguan dari [_tanggal] sampai [_ulangiSampai].
  int get _jumlahMinggu {
    final sampai = _ulangiSampai;
    if (sampai == null) return 1;

    final selisih = sampai.difference(_tanggal).inDays;
    if (selisih < 0) return 1;

    return (selisih ~/ 7) + 1;
  }

  String get _ringkasanPengulangan {
    final jumlah = _jumlahMinggu;
    if (jumlah <= 1) {
      return 'Rentang terlalu pendek - hanya satu jadwal yang akan dibuat.';
    }
    return '$jumlah jadwal akan dibuat, satu setiap 7 hari.';
  }

  Future<void> _pilihUlangiSampai() async {
    final cadangan = _ulangiSampai ?? _tanggalAkhirDefault;
    final awal = cadangan.isBefore(_tanggal) ? _tanggal : cadangan;

    final hasil = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: _tanggal,
      lastDate: DateTimeUtils.today.add(
        const Duration(days: AppConfig.bookingHorizonDays * 4),
      ),
      helpText: 'Ulangi sampai tanggal',
    );

    if (hasil != null) setState(() => _ulangiSampai = hasil);
  }

  /// Memeriksa bentrok terhadap jadwal & reservasi lain pada lab/tanggal yang sama.
  Future<String?> _cariBentrok() async {
    final idLab = _idLab;
    if (idLab == null) return null;

    final tanggalKey = DateTimeUtils.toDateKey(_tanggal);

    final jadwalLain = await ref
        .read(jadwalApiProvider)
        .daftar(dari: tanggalKey, sampai: tanggalKey, labId: idLab);

    for (final jadwal in jadwalLain) {
      if (jadwal.id == widget.jadwalAwal?.id) continue;
      if (DateTimeUtils.isRentangBentrok(
        aMulai: _mulaiMenit,
        aSelesai: _selesaiMenit,
        bMulai: jadwal.mulaiMenit,
        bSelesai: jadwal.selesaiMenit,
      )) {
        return 'Jadwal ${jadwal.mataKuliah} pada ${jadwal.rentangJam} '
            '(${jadwal.tipe.label})';
      }
    }

    final reservasi = await ref
        .read(bookingApiProvider)
        .daftar(labId: idLab, tanggal: tanggalKey);

    for (final booking in reservasi) {
      if (!booking.status.isDisetujui) continue;
      if (DateTimeUtils.isRentangBentrok(
        aMulai: _mulaiMenit,
        aSelesai: _selesaiMenit,
        bMulai: booking.mulaiMenit,
        bSelesai: booking.selesaiMenit,
      )) {
        return 'Kelas pengganti ${booking.mataKuliah} pada ${booking.rentangJam}';
      }
    }

    return null;
  }

  Future<bool> _konfirmasiBentrok(String keterangan) async {
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Jadwal bertabrakan'),
        content: Text(
          'Rentang waktu yang dipilih bertabrakan dengan:\n\n$keterangan\n\n'
          'Tetap simpan jadwal ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Periksa lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tetap simpan'),
          ),
        ],
      ),
    );
    return lanjut ?? false;
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_idLab == null) {
      _tampilkanPesan('Pilih laboratorium terlebih dahulu.');
      return;
    }
    if (_selesaiMenit <= _mulaiMenit) {
      _tampilkanPesan('Jam selesai harus lebih besar daripada jam mulai.');
      return;
    }

    final batasBuka = AppConfig.operatingHourStart * 60;
    final batasTutup = AppConfig.operatingHourEnd * 60;
    if (_mulaiMenit < batasBuka || _selesaiMenit > batasTutup) {
      _tampilkanPesan(
        'Jam harus berada dalam rentang operasional laboratorium '
        '(${AppConfig.operatingHourStart}:00 – ${AppConfig.operatingHourEnd}:00).',
      );
      return;
    }

    final ulangiSampai = _ulangiMingguan && widget.jadwalAwal == null
        ? DateTimeUtils.toDateKey(_ulangiSampai ?? _tanggalAkhirDefault)
        : null;

    setState(() => _menyimpan = true);

    try {
      // Pemeriksaan bentrok di klien hanya mencakup satu tanggal. Untuk jadwal
      // berulang, server yang memeriksa setiap minggu lalu melaporkan minggu
      // mana yang dilewati — memeriksa 16 minggu dari klien berarti 16
      // permintaan HTTP hanya untuk memberi peringatan.
      if (ulangiSampai == null) {
        final keteranganBentrok = await _cariBentrok();
        if (keteranganBentrok != null) {
          if (!mounted) return;
          setState(() => _menyimpan = false);
          final lanjut = await _konfirmasiBentrok(keteranganBentrok);
          if (!lanjut || !mounted) return;
          setState(() => _menyimpan = true);
        }
      }

      final jadwal = LabSchedule(
        // `id == 0` menandai jadwal baru — server yang menentukan ID.
        id: widget.jadwalAwal?.id ?? 0,
        idLab: _idLab!,
        mataKuliah: _mataKuliahController.text.trim(),
        tanggal: DateTimeUtils.toDateKey(_tanggal),
        jamMulai: _jamMulaiKey,
        jamSelesai: _jamSelesaiKey,
        tipe: _tipe,
        namaDosen: _namaDosenController.text.trim().isEmpty
            ? null
            : _namaDosenController.text.trim(),
        catatan: _catatanController.text.trim().isEmpty
            ? null
            : _catatanController.text.trim(),
      );

      final hasil = await ref
          .read(jadwalApiProvider)
          .simpan(jadwal, ulangiSampai: ulangiSampai);

      if (!mounted) return;

      if (hasil.dilewati.isNotEmpty) {
        setState(() => _menyimpan = false);
        await _tampilkanDilewati(hasil);
        if (!mounted) return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      _tampilkanPesan(AppException.from(error).userMessage);
    }
  }

  void _tampilkanPesan(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(pesan),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  /// Menampilkan minggu mana saja yang dilewati karena rentangnya sudah terisi.
  ///
  /// Dilaporkan, bukan didiamkan — kalau tidak, Kepala Laboratorium akan
  /// mengira seluruh rentang berhasil dibuat.
  Future<void> _tampilkanDilewati(HasilSimpanJadwal hasil) async {
    final rincian = hasil.dilewati
        .map((item) {
          final tanggal = DateTime.tryParse(item.tanggal) ?? DateTime(1970);
          return '• ${DateTimeUtils.formatTanggalPanjang(tanggal)}\n'
              '   ${item.alasan}';
        })
        .join('\n\n');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sebagian jadwal dilewati'),
        content: SingleChildScrollView(
          child: Text(
            '${hasil.jumlahDibuat} jadwal dibuat.\n'
            '${hasil.jumlahDilewati} minggu dilewati karena rentangnya sudah '
            'terisi pengajuan:\n\n$rincian',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labs = ref.watch(daftarLabProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            // ---- Header ------------------------------------------------
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
                      widget.jadwalAwal == null
                          ? 'Tambah jadwal lab'
                          : 'Ubah jadwal lab',
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

            // ---- Form --------------------------------------------------
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
                    if (labs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
                        child: InfoBanner(
                          tone: InfoBannerTone.warning,
                          title: 'Belum ada laboratorium',
                          message:
                              'Data laboratorium masih kosong. Tambahkan '
                              'laboratorium terlebih dahulu lewat menu '
                              'Kelola Lab.',
                        ),
                      ),

                    Text('Laboratorium', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _idLab,
                      isExpanded: true,
                      hint: const Text('Pilih laboratorium'),
                      items: [
                        for (final lab in labs)
                          DropdownMenuItem(
                            value: lab.id,
                            child: Text(
                              '${lab.namaLab} · ${lab.kapasitasLabel}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _menyimpan
                          ? null
                          : (value) => setState(() => _idLab = value),
                      validator: (value) =>
                          value == null ? 'Laboratorium wajib dipilih.' : null,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    AppTextField(
                      label: 'Mata kuliah',
                      hint: 'Contoh: Pemrograman Mobile',
                      controller: _mataKuliahController,
                      validator: Validators.mataKuliah,
                      prefixIcon: Icons.menu_book_outlined,
                      enabled: !_menyimpan,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    AppTextField(
                      label: 'Dosen pengampu (opsional)',
                      hint: 'Contoh: Dr. Azlan, M.Kom.',
                      controller: _namaDosenController,
                      prefixIcon: Icons.person_outline_rounded,
                      enabled: !_menyimpan,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    Text('Jenis jadwal', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tipe in ScheduleType.values)
                          ChoiceChip(
                            selected: _tipe == tipe,
                            avatar: Icon(tipe.icon, size: 15),
                            label: Text(tipe.label),
                            onSelected: _menyimpan
                                ? null
                                : (_) => setState(() => _tipe = tipe),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    Text('Waktu', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _PilihanWaktu(
                            label: 'Tanggal',
                            nilai: DateTimeUtils.formatTanggalPendek(_tanggal),
                            icon: Icons.event_outlined,
                            onTap: _menyimpan ? null : _pilihTanggal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: _PilihanWaktu(
                            label: 'Jam mulai',
                            nilai: _jamMulaiKey,
                            icon: Icons.schedule_outlined,
                            onTap: _menyimpan
                                ? null
                                : () => _pilihJam(mulai: true),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSm + 2),
                        Expanded(
                          child: _PilihanWaktu(
                            label: 'Jam selesai',
                            nilai: _jamSelesaiKey,
                            icon: Icons.schedule_outlined,
                            onTap: _menyimpan
                                ? null
                                : () => _pilihJam(mulai: false),
                          ),
                        ),
                      ],
                    ),
                    // ---- Pengulangan mingguan ---------------------------
                    // Hanya untuk jadwal baru: mengubah jadwal yang sudah ada
                    // selalu satu baris, karena setiap kemunculan tersimpan
                    // sebagai baris tersendiri tanpa keterkaitan satu sama lain.
                    if (widget.jadwalAwal == null) ...[
                      const SizedBox(height: AppTheme.spaceMd),
                      SwitchListTile(
                        value: _ulangiMingguan,
                        onChanged: _menyimpan
                            ? null
                            : (nilai) => setState(() {
                                _ulangiMingguan = nilai;
                                _ulangiSampai ??= _tanggalAkhirDefault;
                              }),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Ulangi setiap minggu',
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          _ulangiMingguan
                              ? _ringkasanPengulangan
                              : 'Buat jadwal yang sama pada hari yang sama '
                                    'setiap minggu.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (_ulangiMingguan) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        _PilihanWaktu(
                          label: 'Ulangi sampai',
                          nilai: DateTimeUtils.formatTanggalPendek(
                            _ulangiSampai ?? _tanggalAkhirDefault,
                          ),
                          icon: Icons.event_repeat_outlined,
                          onTap: _menyimpan ? null : _pilihUlangiSampai,
                        ),
                      ],
                    ],

                    const SizedBox(height: AppTheme.spaceMd),

                    AppTextField(
                      label: 'Catatan (opsional)',
                      hint: 'Contoh: praktikum minggu ke-5',
                      controller: _catatanController,
                      validator: Validators.catatan,
                      prefixIcon: Icons.sticky_note_2_outlined,
                      enabled: !_menyimpan,
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    InfoBanner(
                      tone: InfoBannerTone.info,
                      message:
                          'Jadwal bertipe Reguler dan Pemeliharaan akan '
                          'memblokir slot tersebut pada kalender ketersediaan, '
                          'sehingga tidak bisa diajukan sebagai kelas pengganti.',
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    PrimaryButton(
                      label: widget.jadwalAwal == null
                          ? 'Simpan jadwal'
                          : 'Perbarui jadwal',
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

/// Tombol pemilih nilai (tanggal / jam) yang menyesuaikan tema aplikasi.
class _PilihanWaktu extends StatelessWidget {
  const _PilihanWaktu({
    required this.label,
    required this.nilai,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String nilai;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
          border: Border.all(color: theme.dividerTheme.color!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.iconTheme.color),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 1),
                  Text(nilai, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
