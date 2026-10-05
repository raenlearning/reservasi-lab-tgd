import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';

// Inisialisasi Admin SDK sekali untuk seluruh function.
initializeApp();

/**
 * Konfigurasi global.
 *
 * Region `asia-southeast2` (Jakarta) dipilih agar latensi terendah untuk
 * pengguna di Indonesia — harus sama dengan
 * `AppConfig.functionsRegion` di sisi Flutter, karena SDK Flutter memanggil
 * functions pada region tersebut.
 */
setGlobalOptions({
  region: 'asia-southeast2',
  maxInstances: 10,
  memory: '256MiB',
  timeoutSeconds: 60,
});

// Callable — dipanggil langsung dari aplikasi Flutter.
export { submitBooking, reviewBooking } from './bookings';

// Trigger Firestore — pengiriman push notification.
export { onBookingCreated, onBookingReviewed } from './notifications';
