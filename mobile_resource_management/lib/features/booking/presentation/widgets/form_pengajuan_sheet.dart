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
import '../../../../data/models/booking.dart';
import '../../../../data/models/occupancy.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../calendar/providers/calendar_providers.dart';
import '../../providers/booking_providers.dart';

/// Formulir pengajuan reservasi kelas pengganti.
///
/// Alur: pilih laboratorium & tanggal → sistem menampilkan slot yang masih
/// kosong → pilih rentang waktu → isi mata kuliah → kirim.
///
/// Peringatan bentrok di sini bersifat **informatif** (membantu pengguna
/// menghindari kesalahan). Validasi yang mengikat tetap dijalankan di server
/// (`submitBooking`) atau di repository, sehingga tidak bisa dilewati.
class FormPengajuanSheet extends ConsumerStatefulWidget {
  const FormPengajuanSheet({super.key, this.idLabAwal, this.tanggalAwal});

  /// Laboratorium yang sudah dipilih dari halaman sebelumnya.
  final int? idLabAwal;

  /// Tanggal yang sudah dipilih dari kalender.
  final DateTime? tanggalAwal;

  /// Menampilkan formulir sebagai bottom sheet.
  ///
  /// Mengembalikan `true` bila pengajuan berhasil dikirim.
  static Future<bool?> tampilkan(
    BuildContext context, {
    int? idLabAwal,
    DateTime? tanggalAwal,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FormPengajuanSheet(
        idLabAwal: idLabAwal,
        tanggalAwal: tanggalAwal,
      ),
    );
  }

  @override
  ConsumerState<FormPengajuanSheet> createState() => _FormPengajuanSheetState();
}

class _FormPengajuanSheetState extends ConsumerState<FormPengajuanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _mataKuliahController = TextEditingController();
  final _catatanController = TextEditingController();

  int? _idLab;
  late DateTime _tanggal;
  late TimeOfDay _jamMulai;
  late TimeOfDay _jamSelesai;

  @override
  void initState() {
    super.initState();
    _idLab = widget.idLabAwal;
    _tanggal = widget.tanggalAwal ?? DateTimeUtils.today;

    // Rentang awal: satu sesi penuh (2,5 jam) mulai dari jam buka.
    final mulai = AppConfig.operatingHourStart * 60;
    _jamMulai = DateTimeUtils.parseTimeKey(
      DateTimeUtils.timeKeyFromMinutes(mulai),
    );
    _jamSelesai = DateTimeUtils.parseTimeKey(
      DateTimeUtils.timeKeyFromMinutes(mulai + 150),
    );
  }

  @override
  void dispose() {
    _mataKuliahController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  String get _tanggalKey => DateTimeUtils.toDateKey(_tanggal);
  String get _jamMulaiKey => DateTimeUtils.toTimeKey(_jamMulai);
  String get _jamSelesaiKey => DateTimeUtils.toTimeKey(_jamSelesai);

  int get _mulaiMenit => DateTimeUtils.minutesFromTimeKey(_jamMulaiKey);
  int get _selesaiMenit => DateTimeUtils.minutesFromTimeKey(_jamSelesaiKey);

  /// Slot yang bertabrakan dengan rentang waktu yang sedang dipilih.
  ///
  /// Dipanggil dari `build` dengan data ketersediaan yang sudah di-`watch`,
  /// sehingga peringatan ikut terbarui begitu jadwal berubah.
  OccupancySlot? _cariBentrok(LabDayAvailability? availability) {
    if (availability == null) return null;
    for (final slot in availability.slotMemblokir) {
      if (DateTimeUtils.isRentangBentrok(
        aMulai: _mulaiMenit,
        aSelesai: _selesaiMenit,
        bMulai: slot.mulaiMenit,
        bSelesai: slot.selesaiMenit,
      )) {
        return slot;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Pemilih
  // ---------------------------------------------------------------------------

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTimeUtils.today,
      lastDate: DateTimeUtils.today.add(
        const Duration(days: AppConfig.bookingHorizonDays),
      ),
      helpText: 'Pilih tanggal kelas pengganti',
    );
    if (hasil != null) setState(() => _tanggal = hasil);
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
        // Jaga agar jam selesai tetap setelah jam mulai.
        if (DateTimeUtils.minutesFromTimeKey(_jamSelesaiKey) <=
            DateTimeUtils.minutesFromTimeKey(_jamMulaiKey)) {
          _jamSelesai = DateTimeUtils.parseTimeKey(
            DateTimeUtils.timeKeyFromMinutes(
              DateTimeUtils.minutesFromTimeKey(_jamMulaiKey) + 120,
            ),
          );
        }
      } else {
        _jamSelesai = hasil;
      }
    });
  }

  /// Mengisi rentang waktu dari slot kosong yang diketuk pengguna.
  ///
  /// Panjangnya dibatasi [AppConfig.maxSessionMinutes] karena slot kosong bisa
  /// jauh lebih panjang daripada durasi satu sesi kelas.
  void _pilihRentang(TimeRange rentang) {
    final selesai = rentang.mulaiMenit + AppConfig.maxSessionMinutes;
    setState(() {
      _jamMulai = DateTimeUtils.parseTimeKey(
        DateTimeUtils.timeKeyFromMinutes(rentang.mulaiMenit),
      );
      _jamSelesai = DateTimeUtils.parseTimeKey(
        DateTimeUtils.timeKeyFromMinutes(
          selesai > rentang.selesaiMenit ? rentang.selesaiMenit : selesai,
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Kirim
  // ---------------------------------------------------------------------------

  Future<void> _kirim() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_idLab == null) {
      _pesan('Pilih laboratorium terlebih dahulu.', AppErrorCode.notFound);
      return;
    }
    if (_selesaiMenit <= _mulaiMenit) {
      _pesan(
        'Jam selesai harus lebih besar daripada jam mulai.',
        AppErrorCode.invalidTimeRange,
      );
      return;
    }

    final profil = ref.read(currentUserProvider);
    if (profil == null) {
      _pesan('Sesi Anda berakhir. Silakan masuk kembali.',
          AppErrorCode.permissionDenied);
      return;
    }

    final draft = BookingDraft(
      idLab: _idLab!,
      mataKuliah: _mataKuliahController.text.trim(),
      tanggal: _tanggalKey,
      jamMulai: _jamMulaiKey,
      jamSelesai: _jamSelesaiKey,
      catatan: _catatanController.text.trim(),
    );

    // Mengembalikan pesan kesalahan, atau `null` bila berhasil.
    final pesan = await ref
        .read(bookingActionControllerProvider.notifier)
        .ajukan(draft);

    if (!mounted) return;

    if (pesan == null) {
      Navigator.of(context).pop(true);
      return;
    }

    // Gagal — tampilkan pesan dari controller dan segarkan data ketersediaan
    // supaya pengguna melihat kondisi terbaru.
    ref
      ..invalidate(petaKeterisianProvider)
      ..invalidate(ketersediaanLabTanggalProvider);

    _pesan(pesan, ref.read(bookingActionErrorCodeProvider));
  }

  void _pesan(String teks, AppErrorCode? kode) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(teks),
          duration: const Duration(seconds: 5),
          backgroundColor: kode == AppErrorCode.scheduleConflict
              ? const Color(0xFF8A5300)
              : theme.colorScheme.error,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Bangun UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // `daftarLabProvider` sudah mengembalikan daftar siap pakai — datanya
    // berasal dari snapshot kalender yang dimuat berkala.
    final labs = ref.watch(daftarLabProvider);

    final menyimpan = ref.watch(
      bookingActionControllerProvider.select((state) => state.isLoading),
    );

    final availability = _idLab == null
        ? null
        : ref.watch(
            ketersediaanLabTanggalProvider(
              (idLab: _idLab!, tanggal: _tanggalKey),
            ),
          );

    final bentrok = _cariBentrok(availability);
    final durasi = _selesaiMenit - _mulaiMenit;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.96,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajukan kelas pengganti',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          'Pilih slot yang masih kosong',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
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
                              'Data laboratorium belum tersedia. Hubungi '
                              'Kepala Laboratorium.',
                        ),
                      ),

                    // --- Laboratorium -----------------------------------
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
                      onChanged: menyimpan
                          ? null
                          : (value) => setState(() => _idLab = value),
                      validator: (value) =>
                          value == null ? 'Laboratorium wajib dipilih.' : null,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // --- Tanggal ----------------------------------------
                    Text('Tanggal', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _TombolPilih(
                      nilai: DateTimeUtils.formatTanggalPanjang(_tanggal),
                      icon: Icons.event_outlined,
                      onTap: menyimpan ? null : _pilihTanggal,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // --- Ketersediaan -----------------------------------
                    if (availability != null) ...[
                      _PanelKetersediaan(
                        availability: availability,
                        onPilihRentang: menyimpan ? null : _pilihRentang,
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                    ],

                    // --- Rentang waktu ----------------------------------
                    Text('Rentang waktu', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _TombolPilih(
                            nilai: _jamMulaiKey,
                            icon: Icons.schedule_outlined,
                            label: 'Mulai',
                            onTap: menyimpan ? null : () => _pilihJam(mulai: true),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSm + 2),
                        Expanded(
                          child: _TombolPilih(
                            nilai: _jamSelesaiKey,
                            icon: Icons.schedule_outlined,
                            label: 'Selesai',
                            onTap: menyimpan
                                ? null
                                : () => _pilihJam(mulai: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      durasi > 0
                          ? 'Durasi: ${DateTimeUtils.formatDurasi(durasi)} '
                                '(maksimal '
                                '${DateTimeUtils.formatDurasi(AppConfig.maxSessionMinutes)})'
                          : 'Jam selesai harus lebih besar daripada jam mulai.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: durasi > 0
                            ? theme.textTheme.bodySmall?.color
                            : theme.colorScheme.error,
                      ),
                    ),

                    // --- Peringatan bentrok -----------------------------
                    if (bentrok != null) ...[
                      const SizedBox(height: AppTheme.spaceMd),
                      InfoBanner(
                        tone: InfoBannerTone.warning,
                        title: 'Slot ini sudah terpakai',
                        message:
                            '${bentrok.judul} (${bentrok.source.label}) pada '
                            '${bentrok.rentangJam}. Pilih rentang waktu lain '
                            'atau ketuk salah satu slot kosong di atas.',
                      ),
                    ],

                    const SizedBox(height: AppTheme.spaceMd),

                    // --- Mata kuliah ------------------------------------
                    AppTextField(
                      label: 'Mata kuliah',
                      hint: 'Contoh: Pemrograman Mobile',
                      controller: _mataKuliahController,
                      validator: Validators.mataKuliah,
                      prefixIcon: Icons.menu_book_outlined,
                      enabled: !menyimpan,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // --- Catatan ----------------------------------------
                    AppTextField(
                      label: 'Catatan (opsional)',
                      hint: 'Contoh: kelas pengganti pertemuan ke-5',
                      controller: _catatanController,
                      validator: Validators.catatan,
                      prefixIcon: Icons.sticky_note_2_outlined,
                      enabled: !menyimpan,
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    const InfoBanner(
                      tone: InfoBannerTone.info,
                      message:
                          'Pengajuan akan berstatus "Menunggu" sampai '
                          'Kepala Laboratorium menyetujuinya. Anda akan '
                          'menerima notifikasi saat statusnya berubah.',
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    PrimaryButton(
                      label: 'Kirim pengajuan',
                      icon: Icons.send_rounded,
                      isLoading: menyimpan,
                      onPressed: labs.isEmpty ? null : _kirim,
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

// -----------------------------------------------------------------------------
// Panel ketersediaan lab pada tanggal terpilih
// -----------------------------------------------------------------------------

class _PanelKetersediaan extends StatelessWidget {
  const _PanelKetersediaan({
    required this.availability,
    required this.onPilihRentang,
  });

  final LabDayAvailability availability;
  final ValueChanged<TimeRange>? onPilihRentang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kosong = availability.rentangKosong;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: theme.dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.meeting_room_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  availability.namaLab,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm + 2),

          Text(
            'SLOT KOSONG — KETUK UNTUK MENGISI',
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          if (kosong.isEmpty)
            Text(
              'Tidak ada slot kosong pada tanggal ini. Silakan pilih tanggal '
              'atau laboratorium lain.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final rentang in kosong)
                  InkWell(
                    onTap: onPilihRentang == null
                        ? null
                        : () => onPilihRentang!(rentang),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2F5EA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rentang.label,
                        style: const TextStyle(
                          color: Color(0xFF14653C),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

          if (availability.slots.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'SUDAH TERPAKAI',
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
            ),
            const SizedBox(height: 6),
            for (final slot in availability.slots)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      height: 8,
                      width: 8,
                      decoration: BoxDecoration(
                        color: slot.source.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${slot.rentangJam} · ${slot.judul}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tombol pemilih (tanggal / jam)
// -----------------------------------------------------------------------------

class _TombolPilih extends StatelessWidget {
  const _TombolPilih({
    required this.nilai,
    required this.icon,
    this.label,
    this.onTap,
  });

  final String nilai;
  final IconData icon;
  final String? label;
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
                  if (label != null) ...[
                    Text(label!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 1),
                  ],
                  Text(
                    nilai,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
