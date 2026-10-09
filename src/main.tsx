import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './style.css';
try { const saved=localStorage.getItem('entre-lineas-theme'); document.documentElement.dataset.theme=saved==='dark'||saved==='light'?saved:window.matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light'; } catch { document.documentElement.dataset.theme='light'; }
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><App/></React.StrictMode>);
