import React from 'react';
import { createRoot } from 'react-dom/client';
import '../style.css';

function App() {
return (
<div style={{ fontFamily: 'Arial, sans-serif', padding: '30px', textAlign: 'center' }}>
<h1>Koperasi MI Tarbiyatussibyan</h1>
<p>Aplikasi Kasir Koperasi Sekolah</p>
<h2>Selamat Datang!</h2>
<p>Website berhasil berjalan.</p>
</div>
);
}

createRoot(document.getElementById('root')).render(<App />);
