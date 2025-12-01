-- Init script: Importaciones_Animales_Valencia
-- Creates schema, tables and seed data. Uses SKU-based inserts for stock.

-- Creacion de la Base de Datos
CREATE DATABASE IF NOT EXISTS Importaciones_Animales_Valencia;
USE Importaciones_Animales_Valencia;

-- ---------------------------------------------------------
-- Tabla: Proveedores
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS proveedores (
    proveedor_id INT NOT NULL AUTO_INCREMENT,
    nombre_empresa VARCHAR(100) NOT NULL,
    pais_origen VARCHAR(50),
    telefono VARCHAR(20),
    email_contacto VARCHAR(100),
    activo TINYINT DEFAULT 1,
    PRIMARY KEY (proveedor_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Tabla: Clientes
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS clientes (
    cliente_id INT NOT NULL AUTO_INCREMENT,
    nombre_completo VARCHAR(150) NOT NULL,
    dni_cif VARCHAR(20) UNIQUE,
    email VARCHAR(100),
    telefono VARCHAR(20),
    sede_registro VARCHAR(20) NOT NULL COMMENT 'macOS, Windows o Linux',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (cliente_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Tabla: Productos
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS productos (
    producto_id INT NOT NULL AUTO_INCREMENT,
    sku VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    categoria VARCHAR(50),
    precio_base DECIMAL(10,2) NOT NULL,
    peso_kg DECIMAL(6,2),
    PRIMARY KEY (producto_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Tabla: Stock
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS stock (
    stock_id INT NOT NULL AUTO_INCREMENT,
    producto_id INT NOT NULL,
    sede VARCHAR(50) NOT NULL COMMENT 'Ubicacion del inventario',
    cantidad INT DEFAULT 0,
    ultima_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (stock_id),
    FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE,
    UNIQUE KEY unique_stock_sede (producto_id, sede)
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Tabla: Ventas
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS ventas (
    venta_id INT NOT NULL AUTO_INCREMENT,
    cliente_id INT NOT NULL,
    fecha_venta DATETIME DEFAULT CURRENT_TIMESTAMP,
    sede_origen VARCHAR(50) NOT NULL COMMENT 'Sede donde se realizo la venta',
    total DECIMAL(12,2) NOT NULL,
    metodo_pago VARCHAR(50) DEFAULT 'EFECTIVO',
    estado VARCHAR(20) DEFAULT 'COMPLETADO',
    PRIMARY KEY (venta_id),
    FOREIGN KEY (cliente_id) REFERENCES clientes(cliente_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Datos de Ejemplo (Seed Data)
-- ---------------------------------------------------------

INSERT IGNORE INTO proveedores (nombre_empresa, pais_origen, email_contacto) VALUES 
('Granja Global S.A.', 'Espana', 'contacto@granjaglobal.com'),
('Exotic Pets Import', 'Brasil', 'sales@exoticpets.br');

INSERT IGNORE INTO productos (sku, nombre, categoria, precio_base) VALUES 
('PER-001', 'Pastor Aleman Cachorro', 'Caninos', 1200.00),
('GAT-002', 'Gato Persa', 'Felinos', 850.50),
('ALI-003', 'Saco Alimento Premium 20kg', 'Alimentos', 45.00);

-- Inserta stock referenciando los productos por SKU (evita suposiciones de auto_increment)
INSERT IGNORE INTO stock (producto_id, sede, cantidad)
SELECT producto_id, 'Sede Principal (macOS)', 5 FROM productos WHERE sku='PER-001';

INSERT IGNORE INTO stock (producto_id, sede, cantidad)
SELECT producto_id, 'Sede A (Windows)', 3 FROM productos WHERE sku='GAT-002';

INSERT IGNORE INTO stock (producto_id, sede, cantidad)
SELECT producto_id, 'Sede B (Linux)', 50 FROM productos WHERE sku='ALI-003';

-- Fin de script
