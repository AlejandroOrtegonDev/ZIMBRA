/* 
Hacer un select a todos los clientes de la base de datos
*/

import mysql from 'mysql2/promise'; 
import pool from '../config/database.js';

export const obtenerClientes = async () => {
    const [clientes] = await pool.query('SELECT * FROM clientes');
    return clientes;
};