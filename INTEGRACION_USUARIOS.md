# Registro de usuarios desde Administración

Actualización sobre el commit `4cafbf7`, que ya contiene el login y el ajuste
`optimizedLaunch=false`. Se conserva la rama actual y el maestro 01.

## Instalación

1. Guardar `15_Usuarios_API.patch` en la carpeta TechCare que contiene `backend`
   y `frontend`. En la terminal de IntelliJ, situada en esa carpeta, ejecutar:

   ```powershell
   git apply 15_Usuarios_API.patch
   ```

2. El parche crea `13_Usuarios_Procedimientos.sql`. Abrirlo en SSMS y ejecutarlo
   completo una vez sobre la base TechCare existente. Agrega cuatro procedimientos
   y sus permisos; no recrea la base ni modifica las cuentas existentes.
3. Reiniciar el backend y recargar el frontend. Entrar con una cuenta ADMIN,
   como `demo01` si conserva su rol, y abrir **Administración → Nuevo usuario**.

El parche también incluye `14_Pruebas_Usuarios.sql`, una comprobación opcional
para ejecutar en SSMS después del 13. Cada caso revierte sus filas de prueba.
No hace falta ejecutarlo para usar la pantalla.

Después puede eliminarse el archivo `.patch`; conservar el código y los scripts
SQL. El commit y push se hacen como de costumbre en la misma rama.

## Crear una cuenta

- Elegir **Registrar empleado nuevo** y completar su código, nombres y apellidos,
  o **Usar empleado existente** para una persona activa que todavía no tenga cuenta.
- Elegir nombre de usuario, contraseña de 12 a 256 caracteres y su confirmación.
- Seleccionar uno o varios roles y pulsar **Registrar usuario**.
- La cuenta y el empleado quedan activos. La nueva persona ya puede ingresar
  desde la pantalla de login con las credenciales que se le asignaron.

Cada empleado admite una cuenta. El nombre de usuario y el código del empleado
son únicos. El nombre de usuario admite letras sin tildes, números, puntos,
guiones y guiones bajos; los nombres y las contraseñas conservan Unicode.
El registro no cambia la cuenta ni la sesión del administrador que lo realiza.

## Seguridad y guardado

La API recibe la contraseña para calcular PBKDF2-HMAC-SHA256 en Java con 600,000
iteraciones y una sal aleatoria de 16 bytes. SQL recibe únicamente el hash.
Los DTO de respuesta tienen campos explícitos y excluyen contraseña y hash.
El frontend no guarda la contraseña en storage ni en la caché de React Query.

Spring Security exige ADMIN y CSRF para el alta. El actor se toma de la sesión;
un `usuarioActorID` enviado en el formulario no cambia esa identidad. Los SP también
comprueban que el actor siga siendo un ADMIN activo mediante `fnTieneRol`.
Las llamadas a SQL usan parámetros. La operación registra empleado, cuenta y
roles en una transacción con reversión ante errores y restricciones de unicidad.

Esta entrega incluye alta y consulta de usuarios. La edición de roles, desactivación
y restablecimiento de contraseñas requieren operaciones adicionales; no se añaden
acciones incompletas a la pantalla.

## Endpoints

Todos requieren ADMIN. POST requiere además el token CSRF que el cliente ya gestiona.

| Método | Ruta | Procedimiento |
|---|---|---|
| GET | `/api/admin/usuarios` | `spListarUsuarios` |
| GET | `/api/admin/usuarios/{id}` | `spListarUsuarios` |
| POST | `/api/admin/usuarios` | `spRegistrarUsuario` |
| GET | `/api/admin/roles` | `spListarRolesAcceso` |
| GET | `/api/admin/empleados-disponibles` | `spListarEmpleadosDisponibles` |

POST recibe `nombreUsuario`, `contrasena`, `roles[]` y exactamente una opción:
`empleadoId` o `empleadoNuevo: {codigo, nombres, apellidos}`. Devuelve 201 con
la cuenta registrada y un Location que puede consultarse mediante GET.

400: datos o relaciones inválidos; 401: sin sesión; 403: permiso o CSRF;
404: usuario inexistente; 409: usuario, código o cuenta de empleado duplicados;
503: error del servicio de datos.

## Verificación

Las pruebas Java usan JDBC simulado para comprobar permisos, actor, validación,
hash real con sales distintas, respuestas sin secretos y compatibilidad con el login.
Pasaron 70 pruebas Java: 25 de Administración y las 45 existentes.
El frontend se comprueba mediante compilación y navegador con HTTP simulado.
Los scripts SQL se revisan sintácticamente; la ejecución en SQL Server debe
comprobarse en la instancia del proyecto mediante los scripts 13 y 14.
