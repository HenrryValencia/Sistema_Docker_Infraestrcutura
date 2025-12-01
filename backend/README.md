Backend (Node.js/Express)

1) Instalar dependencias:

```bash
cd backend
npm install
```

2) Variables de entorno (opcionales):
- `DB_HOST` (default `127.0.0.1`)
- `DB_PORT` (default `3307` for macOS mapping)
- `DB_USER` (default `root`)
- `DB_PASSWORD` (default `PasswordSeguro123`)
- `DB_NAME` (default `Importaciones_Animales_Valencia`)

3) Iniciar:

```bash
npm start
```

Endpoints:
- `GET /ventas` -> lista ventas (hasta 100)
- `POST /ventas` -> crea venta. Body JSON: `{ cliente_id, sede_origen, total, estado? }`
