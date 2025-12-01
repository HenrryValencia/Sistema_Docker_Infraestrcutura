const mysql = require('mysql2/promise');

// Carga variables de entorno (.env) si existen; usa valores por defecto si no.
// Mejor gestión de credenciales para producción.
const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: process.env.DB_PORT ? Number(process.env.DB_PORT) : 3307,
  user: process.env.DB_USER || 'web',
  password: process.env.DB_PASSWORD || 'Importaciones@2025',
  database: process.env.DB_NAME || 'Importaciones_Animales_Valencia',
  waitForConnections: true,
  connectionLimit: 10
});

module.exports = pool;
