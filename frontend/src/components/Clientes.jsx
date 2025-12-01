import React, { useEffect, useState } from 'react'
import axios from 'axios'

// Componente de clientes: muestra listado y permite crear nuevos clientes.
// Comentarios en español y lenguaje claro para el equipo.
export default function Clientes() {
  const [clientes, setClientes] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [form, setForm] = useState({ nombre_completo: '', dni_cif: '', email: '', telefono: '', sede_registro: 'macOS' })

  const fetchClientes = async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await axios.get('/clientes')
      setClientes(res.data)
    } catch (err) {
      setError('No se pudo cargar los clientes.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchClientes() }, [])

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value })

  const submit = async (e) => {
    e.preventDefault()
    setError(null)
    try {
      await axios.post('/clientes', form)
      setForm({ nombre_completo: '', dni_cif: '', email: '', telefono: '', sede_registro: 'macOS' })
      fetchClientes()
    } catch (err) {
      setError('Error al crear el cliente.')
    }
  }

  return (
    <div>
      <h2>Clientes</h2>
      {error && <div style={{ color: 'red' }}>{error}</div>}
      <form onSubmit={submit} style={{ marginBottom: 16 }}>
        <input name="nombre_completo" value={form.nombre_completo} onChange={handleChange} placeholder="nombre_completo" />
        <input name="dni_cif" value={form.dni_cif} onChange={handleChange} placeholder="dni_cif" />
        <input name="email" value={form.email} onChange={handleChange} placeholder="email" />
        <input name="telefono" value={form.telefono} onChange={handleChange} placeholder="telefono" />
        <select name="sede_registro" value={form.sede_registro} onChange={handleChange}>
          <option value="macOS">macOS</option>
          <option value="Windows">Windows</option>
          <option value="Linux">Linux</option>
        </select>
        <button type="submit">Crear cliente</button>
      </form>

      {loading ? <div>Cargando...</div> : (
        <table border="1" cellPadding="6">
          <thead>
            <tr><th>ID</th><th>Nombre</th><th>DNI/CIF</th><th>Email</th><th>Teléfono</th><th>Sede</th><th>Fecha Registro</th></tr>
          </thead>
          <tbody>
            {clientes.map(c => (
              <tr key={c.cliente_id}>
                <td>{c.cliente_id}</td>
                <td>{c.nombre_completo}</td>
                <td>{c.dni_cif}</td>
                <td>{c.email}</td>
                <td>{c.telefono}</td>
                <td>{c.sede_registro}</td>
                <td>{c.fecha_registro}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
