# Kasir Koperasi Sekolah MI Tarbiyatussibyan

Starter project website kasir berbasis React + Vite + Supabase. Fitur awal: login, peran admin/kasir, master barang, transaksi POS, nota cetak, stok berkurang otomatis, pengeluaran admin, dan laporan laba rugi dasar.

**Penting:** source code ini siap dipasang dan diuji, tetapi belum menjadi website publik. Anda masih perlu membuat proyek Supabase, memasang variabel lingkungan, menjalankan SQL, membuat akun admin, lalu melakukan deployment.

## A. Yang diperlukan
- Supabase: https://supabase.com/
- Node.js LTS: https://nodejs.org/
- GitHub (disarankan): https://github.com/
- Vercel: https://vercel.com/

## B. Siapkan database Supabase
1. Buat proyek baru di Supabase dan simpan kata sandi database dengan aman.
2. Buka **SQL Editor** di dashboard Supabase.
3. Buka file `supabase/schema.sql`, salin seluruh isinya, lalu jalankan di SQL Editor.
4. Buka **Project Settings → API** (atau Connect, sesuai tampilan dashboard). Salin Project URL dan **publishable/anon key**. Jangan salin `service_role` atau secret key ke website.
5. Buat file `.env` di folder proyek:

```env
VITE_SUPABASE_URL=https://PROJECT-ID.supabase.co
VITE_SUPABASE_ANON_KEY=ISI_PUBLISHABLE_ATAU_ANON_KEY
```

6. Di Supabase, buka **Authentication → URL Configuration**. Tambahkan `http://localhost:5173` ke URL yang diizinkan untuk pengembangan. Setelah deploy, tambahkan alamat Vercel juga.

## C. Buat akun admin pertama
1. Buka **Authentication → Users → Add user** di Supabase dan buat akun menggunakan email pengelola koperasi.
2. Di SQL Editor jalankan query berikut dengan email yang benar:

```sql
update public.profiles
set role = 'admin'
where email = 'EMAIL_ADMIN_ANDA';
```

3. Login di website. Pengguna baru secara default mendapat peran `cashier`. Admin dapat mengubah peran melalui SQL Editor.

## D. Jalankan di komputer
Pasang Node.js, buka terminal di folder proyek, lalu jalankan:

```bash
npm install
npm run dev
```

Buka alamat lokal yang muncul (biasanya `http://localhost:5173`). Untuk memeriksa build produksi:

```bash
npm run build
```

## E. Publikasikan tanpa membeli domain
1. Unggah folder proyek ke repository GitHub pribadi.
2. Di Vercel pilih **Add New → Project**, lalu impor repository.
3. Tambahkan environment variables `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY` di pengaturan proyek Vercel.
4. Deploy. Vercel akan memberikan alamat bawaan `*.vercel.app`.
5. Tambahkan alamat tersebut ke Supabase Authentication URL Configuration, lalu uji login dan transaksi dari HP.

## F. Uji sebelum dipakai
- Tambahkan barang contoh dengan stok 10.
- Jual 2 barang. Pastikan stok menjadi 8 dan transaksi tampil di riwayat.
- Coba menjual melebihi stok; transaksi harus ditolak.
- Cetak nota dan periksa nomor nota, total, pembayaran, serta kembalian.
- Cocokkan omzet, HPP, laba kotor, dan pengeluaran.
- Uji menggunakan akun kasir terpisah; kasir seharusnya tidak dapat mengubah master barang atau pengeluaran.
- Hapus data contoh sebelum operasional resmi.

## Batasan versi awal
- Checkout memakai fungsi database atomik untuk menyimpan penjualan, snapshot harga jual/modal, dan mengurangi stok.
- Harga modal saat transaksi disimpan agar perubahan harga berikutnya tidak mengubah HPP transaksi lama.
- Nota dicetak melalui dialog print browser. Izinkan pop-up bila browser memintanya.
- Laporan mencakup omzet, HPP, laba kotor, dan pengeluaran yang dicatat. Retur, diskon, pembelian pemasok lengkap, ekspor Excel/PDF, audit kasir rinci, dan sinkronisasi offline belum termasuk versi pertama.
- Buat backup database berkala. Paket gratis memiliki batas penggunaan dan ketentuan layanan; periksa ketentuan terbaru sebelum dipakai sebagai sistem utama.
