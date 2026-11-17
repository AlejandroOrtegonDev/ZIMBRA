# Fix for http://localhost:3001/api/clients

## Problem
The endpoint `http://localhost:3001/api/clients` was returning "Cannot GET /api/clients" error.

## Root Causes & Fixes

### 1. Wrong import path in `backend/src/api/api.js` (line 4)
- **Bug**: `import {obtenerClientes} from '\repositories\select_client.js'` (missing `..` parent directory)
- **Fix**: Changed to `import {obtenerClientes} from '../repositories/select_client.js'`

### 2. Missing router export in `backend/src/api/api.js`
- **Bug**: The router was defined but never exported
- **Fix**: Added `export default router;` at the end of the file

### 3. Wrong import syntax in `backend/src/app.js`
- **Bug**: `import { router as apiRouter } from './api/api.js'` (trying to import named export from default export)
- **Fix**: Changed to `import apiRouter from './api/api.js'` (default import syntax)

### 4. Duplicate `/api` prefix in `backend/src/app.js`
- **Bug**: `app.use('/api', apiRouter)` combined with routes that already have `/api/` prefix (e.g., `/api/clients`) created `/api/api/clients`
- **Fix**: Changed to `app.use(apiRouter)`

## Verified Working Endpoints
- `GET http://localhost:3001/api/clients` → `{"ok":true,"mensaje":"clientes"}`
- `GET http://localhost:3001/api/estado` → `{"ok":true,"mensaje":"El backend de Zimbra está funcionando"}`
- `GET http://localhost:3001/api/db` → `{"ok":true,"mensaje":"Base de datos conectada"}`