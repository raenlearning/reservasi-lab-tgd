/**
 * Membuat / mempromosikan akun Kepala Laboratorium.
 *
 * Akun Kepala Lab sengaja TIDAK dapat dibuat lewat halaman registrasi aplikasi
 * (mencegah eskalasi hak akses). Skrip ini adalah jalur resmi untuk
 * membuatnya.
 *
 * Pemakaian:
 *
 *   node promote-admin.mjs --identitas=9999000001 --nama="Nama Kepala Lab" \
 *        --password=KataSandiKuat123
 *
 * Argumen:
 *   --identitas  NIDN / nomor identitas unik (wajib)
 *   --nama       Nama lengkap (wajib bila akun belum ada)
 *   --password   Kata sandi awal (wajib bila akun belum ada, min. 8 karakter)
 *   --email      Email internal; default <identitas>@<DOMAIN>
 *   --domain     Domain email internal; default trigunadharma.ac.id
 *
 * Bila akun Firebase Auth sudah ada, skrip hanya memperbarui dokumen
 * `users/{uid}` menjadi jabatan 'Kepala Lab'.
 */

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));

const SERVICE_ACCOUNT_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS
  ? resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS)
  : resolve(__dirname, 'serviceAccountKey.json');

// -----------------------------------------------------------------------------
// Pembacaan argumen
// -----------------------------------------------------------------------------

function arg(nama) {
  const prefiks = `--${nama}=`;
  const ditemukan = process.argv.slice(2).find((a) => a.startsWith(prefiks));
  return ditemukan ? ditemukan.slice(prefiks.length) : undefined;
}

const identitas = arg('identitas');
const nama = arg('nama');
const password = arg('password');
const domain = arg('domain') ?? 'trigunadharma.ac.id';
const email = arg('email') ?? `${identitas ?? ''}@${domain}`;

if (!identitas) {
  console.error(
    'Argumen --identitas wajib diisi.\n\n' +
      'Contoh:\n' +
      '  node promote-admin.mjs --identitas=9999000001 \\\n' +
      '       --nama="Kepala Lab STMIK TD" --password=KataSandiKuat123\n',
  );
  process.exit(1);
}

// -----------------------------------------------------------------------------
// Program utama
// -----------------------------------------------------------------------------

async function main() {
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

  const auth = getAuth(app);
  const db = getFirestore(app);

  console.log('=== Membuat akun Kepala Laboratorium ===\n');
  console.log(`Project     : ${serviceAccount.project_id}`);
  console.log(`Identitas   : ${identitas}`);
  console.log(`Email login : ${email}\n`);

  // --- 1. Akun Firebase Auth ----------------------------------------------
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`= Akun Auth sudah ada (uid: ${userRecord.uid})`);
  } catch {
    if (!nama || !password) {
      console.error(
        'Akun belum ada, sehingga --nama dan --password wajib diisi.\n\n' +
          'Contoh:\n' +
          `  node promote-admin.mjs --identitas=${identitas} \\\n` +
          '       --nama="Kepala Lab STMIK TD" --password=KataSandiKuat123\n',
      );
      process.exit(1);
    }
    if (password.length < 8) {
      console.error('Kata sandi minimal 8 karakter.');
      process.exit(1);
    }

    userRecord = await auth.createUser({
      email,
      password,
      displayName: nama,
    });
    console.log(`+ Akun Auth dibuat (uid: ${userRecord.uid})`);
  }

  // --- 2. Dokumen profil di Firestore -------------------------------------
  const profilRef = db.collection('users').doc(userRecord.uid);
  const profilSnap = await profilRef.get();

  if (profilSnap.exists) {
    await profilRef.update({
      jabatan: 'Kepala Lab',
      nomor_identitas: identitas,
      ...(nama ? { nama } : {}),
      is_active: true,
      updated_at: new Date(),
    });
    console.log('= Dokumen `users` diperbarui -> jabatan: Kepala Lab');
  } else {
    await profilRef.set({
      uid: userRecord.uid,
      nomor_identitas: identitas,
      nama: nama ?? userRecord.displayName ?? 'Kepala Laboratorium',
      email,
      jabatan: 'Kepala Lab',
      fcm_token: null,
      is_active: true,
      created_at: new Date(),
      updated_at: new Date(),
    });
    console.log('+ Dokumen `users` dibuat -> jabatan: Kepala Lab');
  }

  // --- 3. Ringkasan --------------------------------------------------------
  console.log('\n=== Selesai ===\n');
  console.log('Masuk ke aplikasi dengan:');
  console.log(`  NIM/NIDN   : ${identitas}`);
  if (password) console.log(`  Kata sandi : ${password}`);
  console.log(
    '\nSetelah masuk, Kepala Lab dapat:\n' +
      '  - menginput jadwal lab (tab Jadwal),\n' +
      '  - memverifikasi pengajuan (tab Verifikasi),\n' +
      '  - melihat kalender ketersediaan seluruh lab.\n',
  );

  process.exit(0);
}

main().catch((error) => {
  console.error('\nGagal membuat akun Kepala Lab:', error);
  process.exit(1);
});
