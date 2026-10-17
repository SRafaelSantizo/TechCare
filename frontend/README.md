# TechCare — Frontend (React + TypeScript + Vite)

Interfaz del Sistema Integral de Servicio Técnico, Inventario y Facturación
TechCare, con el lenguaje visual **Mercury** adaptado a una aplicación interna
de taller. Repositorio: `frontend/` (el backend Spring Boot permanece en
`backend/`, sin cambios).

---

## 1. Estado real de la integración (auditado contra el código)

El backend del repositorio contiene **un único controlador**:

```
backend/src/main/java/com/techcare/backend/ClienteController.java
```

No hay controladores de autenticación, equipos, órdenes, diagnóstico,
reparación, inventario, compras, facturación, pagos, entrega, reportes ni
administración. Tampoco hay configuración de CORS ni de seguridad. Por lo
tanto:

- **Clientes** es el único módulo conectado (`/api/clientes`).
- El resto de módulos se construyó con la interfaz completa y estados de
  **“pendiente de API”**; no se simulan datos ni se inventan endpoints.
- Un procedimiento SQL (`spCrearOrden`, `spConsumirRepuesto`, …) **no** implica
  una ruta HTTP. Se documentan como dependencia pendiente.

La app incluye un **mapa de integración** navegable en `/integracion` con todas
las operaciones, método/ruta real, DTO, roles, estado y proceso SQL requerido.

### Contrato verificado de Clientes

| Operación | Método y ruta | Entrada | Respuesta | Estado |
|---|---|---|---|---|
| Listar | `GET /api/clientes` | — | `Cliente[]` (sin paginación) | Parcial (pagina/filtra en cliente) |
| Consultar | `GET /api/clientes/{id}` | id | `Cliente` | Conectado |
| Registrar | `POST /api/clientes` | `ClienteDatos` | `Cliente` (201) | Conectado |
| Actualizar / activar / desactivar | `PUT /api/clientes/{id}` | `ClienteDatos` | `Cliente` | Conectado |
| Eliminar | — | — | — | **Ausente** (no existe DELETE; se usa `Activo=false`) |

Notas del contrato real:

- El backend usa `JdbcTemplate.queryForList`, por lo que las claves JSON están
  en **PascalCase** (`ClienteID`, `Nombre`, `TipoClienteID`, …). Los tipos del
  frontend (`src/types/api.ts`) respetan exactamente eso.
- Errores con la forma `{ estado, mensaje, errores? }`; `errores` mapea los
  campos del DTO (`nit`, `nombre`, `email`, …). Se muestran junto al campo.
- El **correo no es obligatorio** en el modelo ni en el DTO.
- No hay autenticación: la identidad del actor y la autorización por rol aún
  **no están implementadas en el servidor**.

---

## 2. Cómo ejecutar

Requisitos: Node 18+ y el backend TechCare (Spring Boot + SQL Server).

```bash
cd frontend
npm install
cp .env.example .env      # Windows: Copy-Item .env.example .env
npm run dev               # http://localhost:5173
```

El servidor de desarrollo de Vite **proxya** `/api` hacia el backend
(`VITE_PROXY_TARGET`, por defecto `http://localhost:8080`), de modo que el
navegador no necesita CORS. El backend no tiene `Access-Control-Allow-Origin`;
por eso **no** se modifica su política CORS: se resuelve con el proxy.

Variables (`.env.example`, sin secretos):

```
VITE_API_BASE_URL=/api
VITE_PROXY_TARGET=http://localhost:8080
```

Otros comandos:

```bash
npm run typecheck   # tsc --noEmit
npm run build       # tsc --noEmit && vite build
npm run preview
```

> El backend se configura con `DB_URL` (variable de entorno) y usa el puerto
> `8080` (`backend/src/main/resources/application.properties`). No se ejecuta
> ningún script SQL, ni se crean datos ni se modifican triggers desde esta
> entrega.

---

## 3. Estructura

```
frontend/src/
  app/          rutas de navegación, sesión, registro de capacidades, queryClient
  components/   ui/ (botones, tablas, diálogos, estados) y layout/ (shell)
  features/     auth, dashboard, clientes, equipos, ordenes, inventario,
                repuestos, compras, proveedores, facturacion, reportes,
                administracion, integracion
  services/     http centralizado, clientes, catálogos de referencia, errores
  types/        DTO reales (PascalCase) y modelos
  styles/       tokens Mercury y estilos globales
  utils/        formatos (GTQ, fechas America/Guatemala) y búsqueda
```

---

## 4. Diseño Mercury

Tokens centralizados en `src/styles/tokens.css` exactamente con los valores
indicados (canvas `#171721`, surface `#1e1e2a`, primary `#5266eb`, etc.).
Barra lateral (~230 px) con grupos *Inicio; Servicio; Inventario y compras;
Facturación; Reportes; Administración*, cabecera de contexto y área de trabajo
amplia. Radios de tarjeta 12 px y de control 32 px, iconos Lucide, transiciones
de ~140 ms con respeto a `prefers-reduced-motion`, foco visible y estados con
texto+color (nunca solo color). Responsive hasta 360 px con navegación en panel
desplegable y tablas con desplazamiento contenido.

---

## 5. Qué está conectado, implementado o pendiente

### Conectado y verificado por compilación de tipos y arranque
- Clientes: listar, consultar, crear, actualizar/activar/desactivar, con
  validación de campos que replica el DTO, manejo de 400/404/409 y errores por
  campo, estados de carga/vacío/error, paginación y búsqueda en cliente.
- Navegación completa, sesión (modo honesto sin autenticación), dashboard,
  mapa de integración.

> Verificado: `npm run typecheck` y `npm run build` correctos y el bundle se
> sirve por HTTP 200. **No** se pudo verificar contra un backend en ejecución en
> esta sesión (requiere SQL Server + `DB_URL`), por lo que las llamadas reales a
> `/api/clientes` quedan **implementadas pero no ejecutadas end-to-end**.

### Implementado pero pendiente de soporte del backend
Toda pantalla y flujo está construido y navegable, pero su acción permanece
deshabilitada porque falta el endpoint. Cada una indica el método/ruta requerido
y el procedimiento SQL de referencia:

- Equipos, órdenes (listado y expediente), dashboard (6 métricas + actividad),
  diagnóstico, reparación, actividades, consumo de repuestos, inventario,
  kardex, repuestos, bodegas, proveedores, compras (registro/recepción/anulación),
  facturación (emisión/anulación), pagos, entrega y administración.
- Los **12 reportes** (R01–R12) listados desde `03_Reportes.sql`.
- **Nueva orden**: el paso *Cliente* ya usa la API real; los pasos de equipo y
  confirmación quedan bloqueados (`POST /api/ordenes` → `spCrearOrden`).

### Pendiente de backend de forma explícita
- **Autenticación y sesión** (`/api/auth/login`, `/api/auth/sesion`). No se
  verifica la contraseña en el navegador ni se simula un administrador local.
  Mientras no exista, la navegación **no oculta** módulos (no se aparenta una
  seguridad inexistente) y `puedeAcceder()` ya está listo para consumir los
  roles cuando el servidor los entregue.
- Autorización por roles en el servidor para cada operación.

---

## 6. Brechas y contradicciones detectadas

1. **No hay endpoint de autenticación** en el backend actual, aunque la
   consigna exige acceso por rol. Documentado; no se simuló.
2. **El SQL exige UsuarioID de la identidad autenticada** (`fnTieneRol`,
   triggers). Sin endpoint de sesión, el frontend no puede aportar ese actor; la
   creación de orden, diagnóstico, consumo, etc. quedan pendientes de esa pieza.
3. **Sin CORS**: se resolvió con proxy de Vite en desarrollo; en producción el
   backend deberá exponer CORS o servirse bajo el mismo origen (no se alteró el
   backend).
4. **Nombres JSON**: el proyecto usa PascalCase por `queryForList`; cualquier
   futura capa de mapeo a camelCase debe actualizar `src/types/api.ts` y los
   servicios, no darse por sentado.
5. **Serialización de fechas**: `java.sql.Timestamp` puede llegar como número o
   ISO. `utils/format.ts` acepta ambos y asume UTC cuando no hay zona; confirmar
   el serializador real antes de confiar en fechas sin zona.
6. **`ClienteController` no pagina ni filtra**: el listado trae el conjunto
   completo; el filtrado/paginación es local y así se rotula en la interfaz.

---

## 7. Contrato requerido (resumen por módulo)

Detalle completo y filtrable en la pantalla **Integración** (`/integracion`).
Cada fila indica operación, `método + ruta` propuestos, entrada, respuesta,
roles y el procedimiento SQL que debe respaldarla (por ejemplo
`POST /api/ordenes` ↔ `spCrearOrden`, `POST /api/reparaciones/{id}/repuestos`
↔ `spConsumirRepuesto`, `POST /api/facturas/{id}/pagos` ↔ `spRegistrarPago`,
`POST /api/ordenes/{id}/entrega` ↔ `spEntregarOrden`).
