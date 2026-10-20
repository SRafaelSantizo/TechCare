# TechCare — Frontend

React, TypeScript y Vite. El backend Spring Boot está en `backend/`.

## Ejecución

```bash
npm ci
npm run dev
```

El proxy de desarrollo envía `/api` al backend; por defecto `http://localhost:8080`.
Se conserva la configuración local existente de `VITE_PROXY_TARGET` y
`VITE_API_BASE_URL`. Iniciar también el backend con su `DB_URL` habitual.

## Módulos conectados

- Acceso: login, sesión al recargar, cierre de sesión y permisos por rol.
- Clientes: listado, consulta, registro, edición, activación/desactivación.
- Equipos: listado, registro, edición, historial y catálogos de tipos, marcas y modelos.
- Nueva orden: selección de cliente y equipo; la confirmación requiere la API de órdenes.

Los demás módulos conservan sus pantallas pendientes de integración. El mapa
`/integracion`, disponible para ADMIN, detalla los endpoints implementados.

## Sesión y permisos

La identidad y los roles vienen de `/api/auth/sesion`; no se guardan contraseñas,
hashes ni tokens de autenticación en localStorage. El navegador envía la cookie
de sesión HttpOnly. Para POST/PUT se obtiene un token CSRF y se envía en la cabecera.
Se renueva después de login/logout y si el filtro rechaza explícitamente un token
vencido antes de ejecutar la operación. Otros errores no repiten escrituras.

Las rutas protegidas redirigen al login cuando no hay sesión. El menú y las
acciones se ajustan a los roles; el servidor comprueba los mismos permisos.
Al salir o vencer la sesión se limpia la caché de consultas para el siguiente usuario.

Las respuestas de Clientes y Equipos conservan PascalCase. Las de acceso usan los
DTO camelCase de `src/services/auth.ts`. Los errores mantienen `{estado,mensaje,errores?}`.

## Verificación

```bash
npm run build
```

La instalación y las cuentas de demostración se describen en `../INTEGRACION_LOGIN.md`.
