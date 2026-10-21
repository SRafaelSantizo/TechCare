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
- Administración (ADMIN): consulta y registro de cuentas con varios roles, para
  un empleado nuevo o un empleado activo que todavía no tenga cuenta.
- Órdenes: recepción con confirmación, listado con filtros, expediente e historial,
  asignación de técnicos y cancelación según el estado. Requiere la actualización SQL 16.
  Diagnósticos y reparaciones existentes se consultan; su registro y los cobros
  se integran en las siguientes etapas.

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

Las respuestas de Clientes y Equipos conservan PascalCase. Acceso, usuarios y órdenes
usan DTO camelCase en sus respectivos archivos de `src/services/`.
Los errores mantienen `{estado,mensaje,errores?}`. El alta usa una solicitud directa
y no guarda la contraseña en la caché de consultas o de mutaciones.

## Verificación

```bash
npm run build
```

La instalación y las cuentas de demostración se describen en `../INTEGRACION_LOGIN.md`.
El alta de usuarios se describe en `../INTEGRACION_USUARIOS.md`.
Órdenes se describe en `../INTEGRACION_ORDENES.md`. Los técnicos sin otros roles
solo consultan las órdenes de las que son responsables. ADMIN y RECEPCION
gestionan ingresos, asignaciones y cancelaciones; CAJA tiene consulta general.
