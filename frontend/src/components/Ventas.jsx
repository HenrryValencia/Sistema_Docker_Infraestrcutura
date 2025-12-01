import React, { useEffect, useState } from 'react'
import axios from 'axios'

// Componente de ventas: muestra ventas y permite crear nuevas.
// Comentarios en español y lenguaje claro para el equipo.
export default function Ventas() {
  const [ventas, setVentas] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [form, setForm] = useState({ cliente_id: '', sede_origen: '', total: '' })

  const fetchVentas = async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await axios.get('/ventas')
      setVentas(res.data)
    } catch (err) {
      setError('No se pudo cargar las ventas.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchVentas() }, [])

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value })

  const submit = async (e) => {
    e.preventDefault()
    setError(null)
    try {
      const payload = { cliente_id: Number(form.cliente_id), sede_origen: form.sede_origen, total: Number(form.total) }
      await axios.post('/ventas', payload)
      setForm({ cliente_id: '', sede_origen: '', total: '' })
      fetchVentas()
    } catch (err) {
      setError('Error al crear la venta.')
    }
  }

  return (
    <div>
      <h2>Ventas</h2>
      {error && <div style={{ color: 'red' }}>{error}</div>}
      <form onSubmit={submit} style={{ marginBottom: 16 }}>
        <input name="cliente_id" value={form.cliente_id} onChange={handleChange} placeholder="cliente_id" />
        <input name="sede_origen" value={form.sede_origen} onChange={handleChange} placeholder="sede_origen" />
        <input name="total" value={form.total} onChange={handleChange} placeholder="total" />
        <button type="submit">Crear</button>
      </form>

      {loading ? <div>Cargando...</div> : (
        <table border="1" cellPadding="6">
          <thead>
            <tr><th>ID</th><th>Cliente</th><th>Fecha</th><th>Sede</th><th>Total</th><th>Estado</th></tr>
          </thead>
          <tbody>
            {ventas.map(v => (
              <tr key={v.venta_id}>
                <td>{v.venta_id}</td>
                <td>{v.cliente_id}</td>
                <td>{v.fecha_venta}</td>
                <td>{v.sede_origen}</td>
                <td>{v.total}</td>
                <td>{v.estado}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
