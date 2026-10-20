# Login, sesión y permisos

Actualización preparada sobre el commit `8ae69b4` de TechCare, después de integrar
Equipos. Usa las tablas y contraseñas existentes; no modifica el maestro 01.

## Instalar en tu proyecto actual

1. Guardar `12_Login.patch` en la carpeta TechCare que contiene `backend`,
   `frontend` y los scripts SQL.
2. Desde la terminal de IntelliJ, en esa carpeta, ejecutar:

   ```bash
   git apply 12_Login.patch
   ```

   El parche coloca los archivos del login y crea `11_Login_Procedimiento.sql`.
   Trabaja en la rama actual; el commit y push se hacen después, como de costumbre.
3. En SSMS, abrir y ejecutar completo `11_Login_Procedimiento.sql` una vez en la
   base existente. Agrega `spConsultarAcceso` y su permiso de ejecución; conserva
   las tablas, usuarios, contraseñas y roles actuales. No ejecutar el maestro ni
   volver a cargar los datos de prueba.
4. En IntelliJ, recargar el proyecto Maven para descargar Spring Security.
   Reiniciar el backend con la misma configuración `DB_URL` y la DLL de JDBC
   que ya funcionaban. No agregar credenciales al código.
5. Ejecutar el frontend como hasta ahora. Si estaba abierto, recargar la página.
   Las rutas del taller pedirán iniciar sesión.

Después de aplicar el parche puede eliminarse `12_Login.patch`. Conservar el
script 11 y los archivos de código. En una instalación nueva, aplicar también
el 11 después del maestro y de los datos/catálogos que correspondan.

## Cuentas de prueba existentes

Si la base conserva los datos de `02_Datos_Prueba.sql`, todas estas cuentas
usan la contraseña de demostración `TechCare2026!`:

| Cuenta | Rol |
|---|---|
| `demo01` | ADMIN |
| `demo02`, `demo03` | RECEPCION |
| `demo04`, `demo05`, `demo06` | TECNICO |
| `demo07`, `demo08` | BODEGA |
| `demo09`, `demo10` | CAJA |

Probar primero `demo01`. Si las cuentas se modificaron en la base, usar sus
credenciales vigentes. El login no crea ni restablece usuarios automáticamente.

## Comportamiento

- Login con usuario y contraseña; un error conserva el nombre de usuario.
- Recuperación de la sesión al recargar. Se usa una cookie HttpOnly y SameSite=Lax.
- Cierre de sesión en el servidor; al salir se limpia la caché del frontend.
- Sesión vencida: vuelve a la pantalla de acceso. Expira tras 30 minutos de
  inactividad y también se pierde al reiniciar el backend, porque reside en memoria.
- Cuentas o empleados inactivos, o cuentas sin roles, no ingresan. La respuesta
  es la misma que para una contraseña incorrecta.
- La contraseña se verifica con PBKDF2-HMAC-SHA256, compatible con los hashes ya
  almacenados. Ni el hash ni la contraseña se devuelven en la respuesta de acceso.
- El identificador de sesión rota al ingresar. POST y PUT requieren token CSRF.
  La capa HTTP del frontend obtiene y renueva ese token automáticamente.
- Diez intentos fallidos bloquean nuevos intentos de esa combinación usuario/IP
  hasta completar una ventana de cinco minutos. Un acceso correcto limpia su contador.
- Los roles de una sesión reflejan los asignados al ingresar. Si cambian en la BD,
  cerrar sesión y volver a ingresar para cargar los nuevos permisos.

No se usan tokens de autenticación en localStorage ni un modo de acceso sin autenticar.
Para servir el backend con HTTPS, configurar `SESSION_COOKIE_SECURE=true`.

## Permisos de las APIs actuales

| Operación | ADMIN | RECEPCION | TECNICO | CAJA | BODEGA |
|---|---|---|---|---|---|
| Ingresar, consultar sesión y salir | Sí | Sí | Sí | Sí | Sí |
| Consultar clientes | Sí | Sí | Sí | Sí | No |
| Crear/editar/activar/desactivar clientes | Sí | Sí | No | No | No |
| Consultar equipos, historial y catálogos | Sí | Sí | Sí | No | No |
| Crear/editar/activar/desactivar equipos | Sí | Sí | No | No | No |

El menú y los botones reflejan estos permisos. Las rutas y operaciones también
se validan en el servidor, aunque alguien intente llamar a la API directamente.
Una cuenta puede tener varios roles. El mapa de integración queda visible para ADMIN.

Órdenes, inventario, compras y caja todavía necesitan sus controladores de negocio.
Las futuras operaciones deben tomar el actor desde `@AuthenticationPrincipal
UsuarioAutenticado`, usando `getUsuarioId()`, y declarar sus permisos en
`SeguridadConfig`. No deben aceptar un UsuarioID arbitrario del formulario.

## Endpoints de acceso

| Método | Ruta | Entrada | Resultado |
|---|---|---|---|
| GET | `/api/auth/csrf` | — | Cookie de sesión y `{headerName, token}` |
| POST | `/api/auth/login` | `{nombreUsuario, contrasena}` + CSRF | `{autenticado, usuario, roles}` |
| GET | `/api/auth/sesion` | Cookie de sesión | Identidad y roles actuales |
| POST | `/api/auth/logout` | Cookie + CSRF | Sesión invalidada |

Para un cliente HTTP distinto del frontend: obtener primero `/api/auth/csrf`,
conservar su cookie y enviar el token en `X-CSRF-TOKEN`. Después de ingresar o
salir, obtener un token nuevo antes de otra escritura. La pantalla ya realiza
estos pasos. Un rechazo explícito `CSRF_INVALIDO` puede renovarse y repetirse
una vez: el filtro lo rechazó antes de ejecutar la operación. Los demás errores
no repiten escrituras automáticamente.

HTTP 400: entrada inválida; 401: credenciales o sesión inválidas; 403: permisos
o CSRF; 429: límite de intentos; 503: no se pudo consultar el acceso en la BD.

## Comprobación y alcance

- 45 pruebas Java aprobadas: 27 nuevas de acceso, contraseña y sesión, más las
  18 existentes. Se comprobaron permisos de los cinco roles, cuenta inactiva,
  roles múltiples, CSRF, errores, cierre de sesión y rotación del identificador.
- La prueba HTTP arranca Tomcat y comprueba cookies reales HttpOnly/SameSite,
  persistencia entre solicitudes y rechazo de cookies antiguas tras login/logout.
- Las pruebas Java sustituyen JDBC por un doble de pruebas: no ejecutan SQL Server.
- Los diez hashes del archivo de datos se verificaron contra la contraseña documentada.
- El script 11 pasó el análisis sintáctico T-SQL. Su ejecución real queda pendiente
  en la instancia del equipo; el paso 3 es necesario antes de usar el login allí.
- Frontend: TypeScript y Vite aprobados. Navegador con HTTP simulado: redirección,
  credenciales incorrectas, recarga, CSRF sin duplicar escrituras, logout, permisos
  y vencimiento de sesión. También se revisó el ancho móvil de la pantalla.

Prueba manual sugerida: ingresar con `demo02`, registrar un cliente, recargar y
salir. Luego ingresar con `demo04`: Clientes/Equipos deben poder consultarse,
pero sus botones de registro y edición estarán deshabilitados. `demo07` no debe
tener acceso a esos módulos aunque se escriba su URL directamente.

Documentación de referencia:
[persistencia de sesión](https://docs.spring.io/spring-security/reference/servlet/authentication/session-management.html),
[protección CSRF](https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html)
y [validación de credenciales](https://docs.spring.io/spring-security/reference/servlet/authentication/passwords/dao-authentication-provider.html).
