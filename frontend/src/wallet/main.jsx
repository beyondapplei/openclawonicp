import React from 'react';
import { createRoot } from 'react-dom/client';
import WalletApp from './WalletApp';
import '../styles.css';

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <WalletApp />
  </React.StrictMode>
);
