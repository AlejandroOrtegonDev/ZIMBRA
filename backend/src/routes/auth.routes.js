// Registro e inicio de sesión (públicas) y perfil (con token)

import { Router } from 'express'
import * as authController from '../controllers/auth.controller.js'
import { autenticar } from '../middlewares/auth.js'

const router = Router()

router.post('/registro', authController.registro)
router.post('/login', authController.login)
router.get('/perfil', autenticar, authController.perfil)

export default router
