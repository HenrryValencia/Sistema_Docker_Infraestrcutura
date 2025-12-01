import React from 'react'
import Ventas from './components/Ventas'
import Clientes from './components/Clientes'

// Página principal: estilo minimalista y elegante, animaciones sutiles.
// Comentarios en español y lenguaje humano para facilitar mantenimiento.
export default function App(){
  return (
    <div className="site-root">
      <header className="nav">
        <div className="nav-inner">
          <div className="brand">Importaciones</div>
          <nav className="menu">
            <a href="#clientes">Clientes</a>
            <a href="#productos">Productos</a>
            <a href="#ventas">Ventas</a>
            <a href="#contacto">Contacto</a>
          </nav>
        </div>
      </header>

      <main>
        <section className="hero">
          <div className="hero-inner">
            <h1>Importaciones de animales y suministros</h1>
            <p className="lead">Calidad global. Tres sedes conectadas. Inventario y ventas en tiempo real.</p>
            <div className="cta-row">
              <a className="btn primary" href="#productos">Ver catálogo</a>
              <a className="btn ghost" href="#ventas">Registrar venta</a>
            </div>
          </div>
          <div className="hero-visual" aria-hidden>
            <div className="card large">
              <div className="card-inner">
                <div className="price">1200€</div>
                <div className="product">Pastor Alemán - Cachorro</div>
              </div>
            </div>
          </div>
        </section>

        <section id="clientes" className="ventas-section">
          <h2>Gestión de clientes</h2>
          <div className="ventas-panel">
            <Clientes />
          </div>
        </section>

        <section id="productos" className="showcase">
          <h2>Nuestros productos</h2>
          <div className="grid">
            <article className="product-card">
              <div className="thumb thumb-dog" />
              <h3>Pastor Alemán</h3>
              <p className="muted">Caninos · SKU PER-001</p>
              <div className="price-row"><span className="price">1200€</span><button className="btn small">Comprar</button></div>
            </article>
            <article className="product-card">
              <div className="thumb thumb-cat" />
              <h3>Gato Persa</h3>
              <p className="muted">Felinos · SKU GAT-002</p>
              <div className="price-row"><span className="price">850,50€</span><button className="btn small">Comprar</button></div>
            </article>
            <article className="product-card">
              <div className="thumb thumb-feed" />
              <h3>Saco Alimento 20kg</h3>
              <p className="muted">Alimentos · SKU ALI-003</p>
              <div className="price-row"><span className="price">45€</span><button className="btn small">Comprar</button></div>
            </article>
          </div>
        </section>

        <section id="ventas" className="ventas-section">
          <h2>Registrar ventas</h2>
          <div className="ventas-panel">
            <Ventas />
          </div>
        </section>

        <section id="contacto" className="contacto">
          <h2>Contacto</h2>
          <p className="muted">¿Necesitas soporte para la sincronización entre sedes? Escríbenos.</p>
        </section>
      </main>

      <footer className="site-footer">
        <div className="footer-inner">
          <div>© {new Date().getFullYear()} Importaciones • Todos los derechos reservados</div>
          <div className="muted">Sede Principal · macOS • Sede A · Windows • Sede B · Linux</div>
        </div>
      </footer>
    </div>
  )
}
