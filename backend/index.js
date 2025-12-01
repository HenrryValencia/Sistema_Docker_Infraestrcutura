const express = require('express');
const bodyParser = require('body-parser');
const pool = require('./db');

const app = express();
app.use(bodyParser.json());

// GET /clientes
app.get('/clientes', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT cliente_id, nombre_completo, dni_cif, email, telefono, sede_registro, fecha_registro FROM clientes ORDER BY fecha_registro DESC LIMIT 100');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al leer clientes' });
  }
});

// POST /clientes
app.post('/clientes', async (req, res) => {
  const { nombre_completo, dni_cif, email, telefono, sede_registro } = req.body;
  if (!nombre_completo || !sede_registro) {
    return res.status(400).json({ error: 'nombre_completo y sede_registro son requeridos' });
  }
  try {
    const [result] = await pool.query('INSERT INTO clientes (nombre_completo, dni_cif, email, telefono, sede_registro) VALUES (?, ?, ?, ?, ?)', [nombre_completo, dni_cif || null, email || null, telefono || null, sede_registro]);
    res.status(201).json({ cliente_id: result.insertId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al crear cliente' });
  }
});

// GET /ventas
app.get('/ventas', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT venta_id, cliente_id, fecha_venta, sede_origen, total, estado FROM ventas ORDER BY fecha_venta DESC LIMIT 100');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al leer ventas' });
  }
});

// POST /ventas
app.post('/ventas', async (req, res) => {
  const { cliente_id, sede_origen, total, estado } = req.body;
  if (!cliente_id || !sede_origen || total == null) {
    return res.status(400).json({ error: 'cliente_id, sede_origen y total son requeridos' });
  }
  try {
    const [result] = await pool.query('INSERT INTO ventas (cliente_id, sede_origen, total, estado) VALUES (?, ?, ?, ?)', [cliente_id, sede_origen, total, estado || 'COMPLETADO']);
    res.status(201).json({ venta_id: result.insertId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al crear venta' });
  }
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Backend API listening on port ${PORT}`);
});
