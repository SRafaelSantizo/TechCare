# Equipos y catálogos

Esta actualización continúa el módulo de Clientes en el proyecto existente.
Agrega ocho endpoints y conecta la pantalla de Equipos. Cada endpoint ejecuta
un procedimiento almacenado; Java no inserta ni actualiza tablas directamente.

## Aplicar en tu proyecto

1. Guardar `10_Equipos_API_v2.patch` en la carpeta TechCare que contiene `backend`,
   `frontend` y los scripts SQL. Se presupone que la API de Clientes ya funciona
   con sus procedimientos almacenados; el maestro puede conservar su versión actual.
2. Desde la terminal de IntelliJ, en esa carpeta, ejecutar:

   ```bash
   git apply 10_Equipos_API_v2.patch
   ```

   Esto modifica y agrega los archivos en la rama actual. No crea ramas ni
   realiza commit o push. Git comprueba los cambios antes de aplicarlos; si la
   versión local tiene un conflicto, lo informa sin aplicar parcialmente el parche.
3. En SSMS ejecutar completo `08_Equipos_Procedimientos.sql`. Crea o actualiza
   los ocho SP y sus permisos; conserva las tablas y los datos existentes.
4. Ejecutar `09_Pruebas_Equipos.sql` desde una conexión de pruebas con permisos
   de administración. Devuelve 29 casos PASS/FAIL. Cada caso se revierte y se
   eliminan los dos clientes y los dos equipos usados para preparar la prueba.
   Requiere los catálogos, dos modelos y un usuario activo de RECEPCION del fixture.
5. Reiniciar el backend desde IntelliJ con la misma configuración `DB_URL` y
   abrir el frontend como hasta ahora. No hay nuevas dependencias de aplicación.
6. En Equipos, registrar un equipo para un cliente activo, editarlo, desactivarlo
   y consultar su historial. Repetir una serie debe mostrar un conflicto sin
   perder los datos del formulario.

Este parche conserva el maestro `01_TechCare_Maestro.sql` y los scripts 02–07.
Para una base existente, el 08 instala Equipos; el 09 permite comprobarlo.
Al preparar una base desde cero con un maestro anterior, aplicar también las
actualizaciones de procedimientos que falten, incluidas las de Clientes y Equipos.
El maestro completo puede consolidarse cuando se cierre la definición de la BD.

## Endpoints

| Método | Ruta | Procedimiento |
|---|---|---|
| GET | `/api/equipos?clienteId=1&serie=ABC&activo=true` (filtros opcionales) | `spListarEquipos` |
| GET | `/api/equipos/{id}` | `spConsultarEquipo` |
| POST | `/api/equipos` | `spRegistrarEquipo` |
| PUT | `/api/equipos/{id}` | `spActualizarEquipo` |
| GET | `/api/equipos/{id}/historial` | `spHistorialEquipo` |
| GET | `/api/catalogos/tipos-equipos` | `spListarTiposEquipo` |
| GET | `/api/catalogos/marcas` | `spListarMarcas` |
| GET | `/api/catalogos/modelos-equipos?marcaId=1&tipoEquipoId=1` (filtros opcionales) | `spListarModelosEquipo` |

POST y PUT reciben:

```json
{
  "clienteId": 1,
  "modeloEquipoId": 1,
  "numeroSerie": "SERIE-PRUEBA-001",
  "descripcion": "Laptop entregada con cargador",
  "activo": true
}
```

Los IDs del ejemplo deben existir. La respuesta usa nombres de columna PascalCase:
`EquipoID`, `ClienteID`, `Cliente`, `ClienteActivo`, `ModeloEquipoID`, `Modelo`,
`MarcaID`, `Marca`, `TipoEquipoID`, `TipoEquipo`, `NumeroSerie`, `Descripcion`,
`Activo` y `TieneOrdenes`. POST devuelve 201 y `Location`; los otros endpoints
devuelven 200. El historial vacío es `[]`; equipo inexistente es 404.

## Reglas y errores

- Descripción y serie obligatorias: hasta 500 y 80 caracteres respectivamente.
- Serie única; cliente y modelo existentes. Un equipo activo requiere cliente activo.
- Se conservan equipos inactivos y su historial. No se implementa DELETE.
- Con órdenes, propietario, modelo y serie permanecen fijos. Sí pueden cambiar
  descripción y Activo. El formulario bloquea esos tres campos y SQL los valida.
- Escrituras con TRY/CATCH, XACT_ABORT, COMMIT/ROLLBACK, SAVE TRANSACTION y THROW.
  La restricción UNIQUE resuelve también series duplicadas por solicitudes simultáneas.
- El rol `techcare_app` tiene EXECUTE y DENY de escritura directa sobre Equipo.
  Las cuentas administrativas conservan sus privilegios; no sustituyen al rol de la aplicación.
- HTTP 400: datos inválidos o relaciones inválidas; 404: equipo inexistente;
  409: serie duplicada o cambio prohibido por historial; 500: error inesperado.
  Se conserva la forma `{estado, mensaje, errores?}` utilizada por el frontend.

## Interfaz y alcance

Equipos permite búsqueda, filtro por cliente/estado, paginación, registro, edición,
activación/desactivación e historial. Marcas, modelos y tipos se cargan desde la BD.
El detalle de Cliente enlaza a sus equipos; Nueva orden ya permite seleccionar un
equipo real del cliente. Confirmar una orden requiere integrar autenticación y
el endpoint de órdenes; esa confirmación continúa deshabilitada.

Esta entrega consulta catálogos existentes. No incorpora todavía pantallas para
crear marcas o modelos. La autenticación y autorización HTTP siguen pendientes,
al igual que antes de esta actualización.

## Validación

- Compilación Java y 17 pruebas de Equipos/catálogos más una de contexto Spring aprobadas.
  MockMvc usa JDBC simulado; estas pruebas no ejecutan SQL Server.
- Frontend: TypeScript y compilación Vite aprobados.
- Navegador de prueba: registro, conflicto conservando los datos, edición,
  desactivación, historial vacío/con órdenes, bloqueo de identidad con historial,
  selección en Nueva orden y ancho móvil verificados con HTTP simulado.
- Scripts 01, 08 y 09 analizados con SQLFluff T-SQL, sin errores de análisis.
  Esto no equivale a compilarlos o ejecutarlos en SQL Server.
- La comprobación real de los 29 casos SQL corresponde al paso 4.

Para repetir las pruebas Java desde IntelliJ: ejecutar `EquipoControllerTests`.
La prueba de contexto existente necesita `DB_URL`, igual que la aplicación.
