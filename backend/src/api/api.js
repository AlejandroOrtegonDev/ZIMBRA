import { Router } from 'express';
import pool from '../config/database.js';
import { comprobarConexion } from '../config/database.js';

const router = Router();

router.get('/api/estado', (req, res) => {
    res.json({
        ok: true,
        mensaje: 'El backend de Zimbra está funcionando'
    });
});

router.get('/api/db', async (req, res) => {
    try {
        await comprobarConexion();
        res.json({
            ok: true,
            mensaje: 'Base de datos conectada'
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({
            ok: false,
            mensaje: 'No se pudo conectar con la base de datos'
        });
    }
});

export default router;