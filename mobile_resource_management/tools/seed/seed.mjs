/**
 * Seed data awal untuk Mobile Resource Management STMIK Triguna Dharma.
 *
 * Mengisi koleksi `labs` dan contoh `lab_schedules` sehingga kalender
 * ketersediaan langsung dapat didemokan tanpa harus menginput manual.
 *
 * Pemakaian:
 *
 *   1. Unduh service account key:
 *      Firebase Console -> Project settings -> Service accounts
 *      -> Generate new private key  -> simpan sebagai
 *      tools/seed/serviceAccountKey.json
 *
 *   2. npm install
 *      node seed.mjs
 *
 * Opsi:
 *   --reset   Hapus lebih dulu seluruh dokumen `labs` dan `lab_schedules`.
 *   --hari=N  Rentang hari jadwal contoh yang dibuat (default 21).
 *
 * PERINGATAN: jangan pernah meng-commit `serviceAccountKey.json`.
 */

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));

// -----------------------------------------------------------------------------
// Konfigurasi
// -----------------------------------------------------------------------------

const SERVICE_ACCOUNT_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS
  ? resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS)
  : resolve(__dirname, 'serviceAccountKey.json');

const args = process.argv.slice(2);
const RESET = args.includes('--reset');
const HARI = Number(
  (args.find((a) => a.startsWith('--hari=')) ?? '--hari=21').split('=')[1],
);

/** Daftar laboratorium komputer STMIK Triguna Dharma. */
const LABS = [
  {
    nama_lab: 'Lab Komputer 1',
    kapasitas: 40,
    lokasi: 'Gedung B, Lantai 1',
    fasilitas: ['40 PC', 'Proyektor', 'AC', 'Whiteboard'],
  },
  {
    nama_lab: 'Lab Komputer 2',
    kapasitas: 40,
    lokasi: 'Gedung B, Lantai 1',
    fasilitas: ['40 PC', 'Proyektor', 'AC', 'Whiteboard'],
  },
  {
    nama_lab: 'Lab Multimedia',
    kapasitas: 30,
    lokasi: 'Gedung B, Lantai 2',
    fasilitas: ['30 iMac', 'Proyektor', 'AC', 'Scanner'],
  },
  {
    nama_lab: 'Lab Jaringan',
    kapasitas: 25,
    lokasi: 'Gedung C, Lantai 1',
    fasilitas: ['25 PC', 'Rack Cisco', 'Router', 'Switch', 'AC'],
  },
  {
    nama_lab: 'Lab Pemrograman',
    kapasitas: 35,
    lokasi: 'Gedung C, Lantai 2',
    fasilitas: ['35 PC', 'Proyektor', 'AC', 'Whiteboard'],
  },
];

/**
 * Pola jadwal praktikum mingguan.
 *
 * `hari` mengikuti konvensi JavaScript: 0 = Minggu, 1 = Senin, ..., 6 = Sabtu.
 */
const POLA_MINGGUAN = [
  // Senin
  { hari: 1, lab: 'Lab Komputer 1', mulai: '08:00', selesai: '10:30', mk: 'Algoritma dan Pemrograman', dosen: 'Dr. Azlan, M.Kom.' },
  { hari: 1, lab: 'Lab Komputer 2', mulai: '10:30', selesai: '13:00', mk: 'Basis Data', dosen: 'Rina Sari, M.Kom.' },
  { hari: 1, lab: 'Lab Jaringan', mulai: '13:00', selesai: '15:30', mk: 'Jaringan Komputer', dosen: 'Budi Hartono, M.T.' },

  // Selasa
  { hari: 2, lab: 'Lab Pemrograman', mulai: '08:00', selesai: '10:30', mk: 'Pemrograman Web', dosen: 'Siti Aminah, M.Kom.' },
  { hari: 2, lab: 'Lab Multimedia', mulai: '10:30', selesai: '13:00', mk: 'Desain Grafis', dosen: 'Andi Pratama, M.Ds.' },
  { hari: 2, lab: 'Lab Komputer 1', mulai: '15:30', selesai: '18:00', mk: 'Struktur Data', dosen: 'Dr. Azlan, M.Kom.' },

  // Rabu
  { hari: 3, lab: 'Lab Komputer 2', mulai: '08:00', selesai: '10:30', mk: 'Sistem Operasi', dosen: 'Hendra Wijaya, M.Kom.' },
  { hari: 3, lab: 'Lab Pemrograman', mulai: '10:30', selesai: '13:00', mk: 'Pemrograman Mobile', dosen: 'Siti Aminah, M.Kom.' },
  { hari: 3, lab: 'Lab Jaringan', mulai: '13:00', selesai: '15:30', mk: 'Keamanan Jaringan', dosen: 'Budi Hartono, M.T.' },

  // Kamis
  { hari: 4, lab: 'Lab Komputer 1', mulai: '08:00', selesai: '10:30', mk: 'Kecerdasan Buatan', dosen: 'Dr. Azlan, M.Kom.' },
  { hari: 4, lab: 'Lab Multimedia', mulai: '13:00', selesai: '15:30', mk: 'Animasi Digital', dosen: 'Andi Pratama, M.Ds.' },

  // Jumat
  { hari: 5, lab: 'Lab Komputer 2', mulai: '08:00', selesai: '10:30', mk: 'Rekayasa Perangkat Lunak', dosen: 'Rina Sari, M.Kom.' },
  { hari: 5, lab: 'Lab Pemrograman', mulai: '13:00', selesai: '15:30', mk: 'Pemrograman Mobile', dosen: 'Siti Aminah, M.Kom.' },

  // Sabtu
  { hari: 6, lab: 'Lab Komputer 1', mulai: '08:00', selesai: '10:30', mk: 'Praktikum Basis Data Lanjut', dosen: 'Hendra Wijaya, M.Kom.' },
];

/** Satu jadwal pemeliharaan contoh. */
const PEMELIHARAAN = {
  hari: 3,
  lab: 'Lab Multimedia',
  mulai: '15:30',
  selesai: '17:00',
  mk: 'Pemeliharaan Perangkat Multimedia',
  catatan: 'Kalibrasi proyektor & pembaruan sistem',
};

// -----------------------------------------------------------------------------
// Utilitas
// -----------------------------------------------------------------------------

const pad = (value) => String(value).padStart(2, '0');

/**
 * Granularitas slot kunci keterisian, dalam menit.
 *
 * HARUS sama dengan `AppConfig.slotMinutes` (Flutter) dan `SLOT_MENIT`
 * (functions/src/constants.ts). Kunci ini yang membuat pemeriksaan jadwal
 * bentrok bebas race condition tanpa Cloud Functions.
 */
const SLOT_MENIT = 30;

/** Indeks slot yang tercakup rentang [mulai, selesai) — bersifat half-open. */
function slotIndicesCovered(mulaiMenit, selesaiMenit) {
  if (selesaiMenit <= mulaiMenit) return [];
  const pertama = Math.floor(mulaiMenit / SLOT_MENIT);
  const terakhir = Math.floor((selesaiMenit - 1) / SLOT_MENIT);
  const hasil = [];
  for (let i = pertama; i <= terakhir; i += 1) hasil.push(i);
  return hasil;
}

function slotLockDocId(idLab, tanggal) {
  return `${idLab}_${tanggal}`;
}

/**
 * Akumulator kunci slot. Dikumpulkan di memori lalu ditulis sekali di akhir,
 * supaya satu laboratorium pada satu tanggal hanya menghasilkan satu dokumen.
 */
const kunciSlot = new Map();

function catatKunci(idLab, tanggal, mulaiMenit, selesaiMenit, pemilik) {
  const docId = slotLockDocId(idLab, tanggal);
  if (!kunciSlot.has(docId)) {
    kunciSlot.set(docId, { id_lab: idLab, tanggal, slots: {} });
  }
  const entri = kunciSlot.get(docId);
  for (const indeks of slotIndicesCovered(mulaiMenit, selesaiMenit)) {
    entri.slots[String(indeks)] = pemilik;
  }
}

function toDateKey(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function minutesFromTimeKey(timeKey) {
  const [hour, minute] = timeKey.split(':').map(Number);
  return hour * 60 + minute;
}

function semesterAktif(date) {
  // Semester ganjil: Agustus - Januari; genap: Februari - Juli.
  const bulan = date.getMonth() + 1;
  const ganjil = bulan >= 8 || bulan <= 1;
  const tahunAwal = bulan >= 8 ? date.getFullYear() : date.getFullYear() - 1;
  return ganjil
    ? `Ganjil ${tahunAwal}/${tahunAwal + 1}`
    : `Genap ${tahunAwal}/${tahunAwal + 1}`;
}

// -----------------------------------------------------------------------------
// Program utama
// -----------------------------------------------------------------------------

async function main() {
  console.log('=== Seed data Mobile Resource Management ===\n');

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(readFileSync(SERVICE_ACCOUNT_PATH, 'utf8'));
  } catch {
    console.error(
      `Tidak dapat membaca service account key di:\n  ${SERVICE_ACCOUNT_PATH}\n\n` +
        'Unduh dari Firebase Console -> Project settings -> Service accounts\n' +
        '-> Generate new private key, lalu simpan sebagai\n' +
        'tools/seed/serviceAccountKey.json',
    );
    process.exit(1);
  }

  const app = initializeApp({
    credential: cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });

  const db = getFirestore(app);
  console.log(`Project  : ${serviceAccount.project_id}`);

  // --- Opsi reset ----------------------------------------------------------
  if (RESET) {
    console.log('\nMenghapus data lama (--reset)...');
    for (const koleksi of ['labs', 'lab_schedules', 'slot_locks']) {
      const snapshot = await db.collection(koleksi).get();
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log(`  ${koleksi}: ${snapshot.size} dokumen dihapus`);
    }
  }

  // --- 1. Laboratorium -----------------------------------------------------
  console.log('\n[1/3] Mengisi koleksi `labs`...');
  const labIdByName = new Map();

  for (const lab of LABS) {
    const existing = await db
      .collection('labs')
      .where('nama_lab', '==', lab.nama_lab)
      .limit(1)
      .get();

    if (!existing.empty) {
      const doc = existing.docs[0];
      labIdByName.set(lab.nama_lab, doc.id);
      console.log(`  = ${lab.nama_lab} (sudah ada, id: ${doc.id})`);
      continue;
    }

    const ref = await db.collection('labs').add({
      ...lab,
      is_active: true,
      created_at: new Date(),
      updated_at: new Date(),
    });
    labIdByName.set(lab.nama_lab, ref.id);
    console.log(`  + ${lab.nama_lab} (id: ${ref.id})`);
  }

  // --- 2. Jadwal contoh ----------------------------------------------------
  console.log(`\n[2/3] Mengisi contoh jadwal untuk ${HARI} hari ke depan...`);

  const hariIni = new Date();
  hariIni.setHours(0, 0, 0, 0);

  let jumlahJadwal = 0;
  let jumlahPemeliharaan = 0;

  for (let offset = 0; offset < HARI; offset += 1) {
    const tanggal = new Date(hariIni);
    tanggal.setDate(tanggal.getDate() + offset);

    const tanggalKey = toDateKey(tanggal);
    const hariKe = tanggal.getDay();
    const semester = semesterAktif(tanggal);

    const jadwalHariIni = POLA_MINGGUAN.filter((p) => p.hari === hariKe);

    for (const pola of jadwalHariIni) {
      const idLab = labIdByName.get(pola.lab);
      if (!idLab) continue;

      const mulaiMenit = minutesFromTimeKey(pola.mulai);
      const selesaiMenit = minutesFromTimeKey(pola.selesai);

      const ref = await db.collection('lab_schedules').add({
        id_lab: idLab,
        mata_kuliah: pola.mk,
        nama_dosen: pola.dosen,
        tanggal: tanggalKey,
        jam_mulai: pola.mulai,
        jam_selesai: pola.selesai,
        mulai_menit: mulaiMenit,
        selesai_menit: selesaiMenit,
        tipe: 'Reguler',
        semester,
        dibuat_oleh: 'seed-script',
        created_at: new Date(),
        updated_at: new Date(),
      });

      // Jadwal Reguler memblokir slot -> kunci harus ikut ditulis.
      catatKunci(idLab, tanggalKey, mulaiMenit, selesaiMenit, `s:${ref.id}`);
      jumlahJadwal += 1;
    }

    // Pemeliharaan rutin setiap dua minggu.
    if (offset % 14 === 0 && hariKe === PEMELIHARAAN.hari) {
      const idLab = labIdByName.get(PEMELIHARAAN.lab);
      if (idLab) {
        const mulaiPemeliharaan = minutesFromTimeKey(PEMELIHARAAN.mulai);
        const selesaiPemeliharaan = minutesFromTimeKey(PEMELIHARAAN.selesai);

        const refPemeliharaan = await db.collection('lab_schedules').add({
          id_lab: idLab,
          mata_kuliah: PEMELIHARAAN.mk,
          tanggal: tanggalKey,
          jam_mulai: PEMELIHARAAN.mulai,
          jam_selesai: PEMELIHARAAN.selesai,
          mulai_menit: mulaiPemeliharaan,
          selesai_menit: selesaiPemeliharaan,
          tipe: 'Pemeliharaan',
          catatan: PEMELIHARAAN.catatan,
          semester,
          dibuat_oleh: 'seed-script',
          created_at: new Date(),
          updated_at: new Date(),
        });

        catatKunci(
          idLab,
          tanggalKey,
          mulaiPemeliharaan,
          selesaiPemeliharaan,
          `s:${refPemeliharaan.id}`,
        );
        jumlahPemeliharaan += 1;
      }
    }
  }

  console.log(`  + ${jumlahJadwal} jadwal reguler`);
  console.log(`  + ${jumlahPemeliharaan} jadwal pemeliharaan`);

  // --- 3. Kunci keterisian slot --------------------------------------------
  console.log('\n[3/3] Menulis kunci keterisian slot (`slot_locks`)...');

  for (const [docId, entri] of kunciSlot) {
    await db
      .collection('slot_locks')
      .doc(docId)
      .set({ ...entri, updated_at: new Date() });
  }

  console.log(`  + ${kunciSlot.size} dokumen kunci slot`);
  console.log(
    '\n  Penting: kunci slot WAJIB ada, karena inilah yang membuat\n' +
      '  pemeriksaan jadwal bentrok bebas race condition tanpa Cloud Functions.',
  );

  console.log('\n=== Selesai ===');
  console.log(
    '\nLangkah berikutnya:\n' +
      '  1. Buat akun Kepala Laboratorium (lihat README bagian "Menyiapkan akun\n' +
      '     Kepala Laboratorium").\n' +
      '  2. Buka aplikasi -> masuk -> tab Kalender untuk melihat ketersediaan.\n',
  );

  process.exit(0);
}

main().catch((error) => {
  console.error('\nSeed gagal:', error);
  process.exit(1);
});
