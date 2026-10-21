# TechCare - Diseño de base de datos

Este paquete cubre la parte de base de datos del proyecto UMG: modelo relacional,
normalización, objetos SQL, datos ficticios, reportes y pruebas ejecutables.
Clientes, Equipos y recepción de Órdenes tienen API e interfaz conectadas. El acceso usa las cuentas y
roles de la BD, con login, sesión y cierre de sesión. Los demás módulos y manuales
con capturas aún deben completarse.

Para incorporar el login a una base existente: [INTEGRACION_LOGIN.md](INTEGRACION_LOGIN.md).
La actualización requiere ejecutar `11_Login_Procedimiento.sql` una vez; conserva
las tablas, usuarios y contraseñas existentes. El maestro 01 no se modifica.
Una instalación nueva con un maestro anterior debe incluir también las
actualizaciones 06 (Clientes), 08 (Equipos), 11 (Acceso), 13 (Usuarios) y 16 (Órdenes).

Administración permite consultar y registrar cuentas, empleados y roles desde
una sesión ADMIN. Instalación: [INTEGRACION_USUARIOS.md](INTEGRACION_USUARIOS.md).
En una base existente se ejecuta `13_Usuarios_Procedimientos.sql` una vez.

Órdenes permite registrar ingresos, consultar el expediente y su historial,
asignar técnicos antes del diagnóstico y cancelar cuando el estado lo permite.
Instalación: [INTEGRACION_ORDENES.md](INTEGRACION_ORDENES.md).
En una base existente se ejecuta `16_Ordenes_Procedimientos.sql` una vez.
Los técnicos sin otros roles consultan únicamente sus órdenes, también desde el
historial de Equipos. Registrar diagnósticos, reparaciones y cobros desde la API
queda pendiente de las siguientes integraciones.

## Ejecución desde cero

1. Utilizar una instancia de **SQL Server 2019 o posterior** y SQL Server Management Studio.
2. Abrir `01_TechCare_Maestro.sql` y ejecutarlo completo con un usuario autorizado
   para crear bases de datos. Crea `TechCare`; no contiene DROP ni elimina una base existente.
   Si TechCare ya contiene tablas, detiene las secciones restantes mediante NOEXEC.
3. Ejecutar `02_Datos_Prueba.sql` una sola vez sobre la base recién creada.
4. Ejecutar `03_Reportes.sql`; los filtros iniciales NULL muestran todos los resultados.
5. Ejecutar `04_Pruebas_Integridad.sql`. Los mensajes PASS son la evidencia obtenida
   en su instancia; un THROW señala una prueba fallida.

Los separadores GO son del cliente SSMS/sqlcmd. No enviar el archivo entero como
una sola sentencia JDBC. Alternativa de consola con autenticación integrada:

```bash
sqlcmd -S localhost -E -b -i 01_TechCare_Maestro.sql
sqlcmd -S localhost -E -b -i 02_Datos_Prueba.sql
sqlcmd -S localhost -E -b -i 03_Reportes.sql
sqlcmd -S localhost -E -b -i 04_Pruebas_Integridad.sql
```

Si utiliza autenticación SQL, configurar las credenciales fuera del código fuente.
Todas las fechas están en UTC y los importes del fixture se expresan en quetzales.
TasaImpuesto es una tasa de prueba configurable (0.1200); no constituye configuración fiscal.

## Decisiones que debe conocer el equipo

- **35 tablas originales**, más AsignacionOrden en la actualización 16. Cliente -> Equipo -> Orden determina el propietario. Orden
  no repite ClienteID; `vOrdenResumen` lo presenta mediante JOIN y preserva 3FN.
  No se permite cambiar propietario, serie ni modelo de un equipo con órdenes.
- **Un diagnóstico consolidado y una reparación por orden.** Las revisiones del
  equipo son órdenes nuevas; las tareas se guardan en ReparacionActividad. No se
  presupone que toda orden esté diagnosticada, reparada o facturada.
- Las N:M principales son UsuarioRol, ProveedorRepuesto, Inventario y
  ReparacionActividad; todas tienen PK compuesta. Los detalles usan encabezado + línea.
- **Stock = entradas - salidas.** Inventario guarda sólo la pareja Bodega/Repuesto
  y su mínimo; `vInventario.Existencia` se calcula desde el kardex. Toda modificación
  de existencias implica insertar un movimiento con origen y nunca editar un contador.
  Movimiento guarda una FK real a DetalleCompra o ReparacionRepuesto, nunca un ID
  polimórfico sin relación. Cantidad, bodega y repuesto se obtienen del detalle origen.
- ExistenciaResultante es la fotografía histórica del saldo al registrar el movimiento,
  validada por trigger contra el kardex ordenado por MovimientoID. Se rechazan
  movimientos fechados antes de movimientos ya registrados en la misma pareja.
- Las compras se reciben completas, una sola vez. Las pendientes no aumentan stock.
  Cada línea puede tener su propia bodega. No se implementan recepciones parciales.
- El costo del consumo es el **costo de referencia congelado** en ese momento.
  No implementa valoración por promedio ponderado o PEPS. PrecioUnitario conserva
  la venta histórica; los valores de compras, consumos y facturas no se reescriben.
- Factura conserva identificación fiscal, tasa histórica, fecha y estado. Sus líneas
  inmutables conservan conceptos, cantidades y precios. **Subtotal, Impuesto, Total,
  Pagado, Saldo y EstadoPago** se obtienen de `vFacturaSaldo`; no se editan a mano.
  El impuesto se redondea a dos decimales por factura. `fnTotalOrden` devuelve subtotal.
- La factura es cero o una por orden y tiene cero o varios pagos. No hay crédito:
  entregar exige reparación terminada, factura emitida y saldo cero.
- Las transiciones autorizadas están en TransicionEstadoOrden. El trigger escribe
  HistorialEstadoOrden por cada cambio, incluso si se actualiza desde SQL.
  La autorización de reparación se documenta en la observación del cambio de estado.
- Cancelación de orden: sólo antes de reparar. Anulación de compra: sólo pendiente.
  Anulación de factura: sólo sin pagos ni entrega. No se regeneran facturas para una
  orden anulada; devoluciones, notas de crédito, reembolsos, ajustes y traslados de
  inventario requieren procesos adicionales y no están habilitados en este alcance.

## Objetos y protección de integridad

El maestro incluye 7 vistas, 4 funciones, 14 procedimientos transaccionales,
17 índices no agrupados explícitos y 16 triggers de validación/auditoría/inmutabilidad, uno por tabla protegida.
Las PK/UNIQUE también generan sus índices internos. Todas las FK usan NO ACTION.
El estado de una factura pagada/parcial/pendiente se calcula, no se sincroniza a mano.

Los procedimientos bloquean la fila de Inventario con UPDLOCK/HOLDLOCK antes de
calcular stock, y la fila de Factura antes de aceptar pagos. Así serializan las
operaciones sobre una misma pareja o factura. Compras bloquean parejas en orden
bodega/repuesto. Los triggers de saldo/kardex también validan INSERT de varias filas.
Ante interbloqueo, la API debe reintentar la transacción completa, no una sola sentencia.

Las transacciones usan TRY/CATCH, XACT_ABORT y SAVE TRANSACTION para llamadas
anidadas. Si una transacción externa queda no confirmable, el invocador debe ejecutar
ROLLBACK completo; el script de datos y las pruebas ya manejan este caso.

El rol de base de datos **techcare_app** tiene SELECT/EXECUTE y mantenimiento de
maestros, pero DENY a INSERT/UPDATE/DELETE sobre tablas transaccionales. El backend
debe usar un principal miembro de este rol, **sin db_owner, sysadmin ni permisos de
alteración**. La cadena de propiedad permite que los procedimientos escriban.
No se crea un login con contraseña predefinida. Para agregar el usuario existente:

```sql
USE TechCare;
ALTER ROLE techcare_app ADD MEMBER [usuario_sql_del_backend];
```

La API toma UsuarioID de la identidad autenticada; no debe aceptar un actor arbitrario
del cuerpo HTTP. Restringe usuarios/roles y catálogos administrativos a ADMIN.
Los triggers/constraints rechazan sobrepagos, stock negativo, fuentes inválidas,
saltos de estado y modificaciones de historia. La prohibición de DML directo del rol
garantiza que un flujo con varios pasos se ejecute completo por su procedimiento.
Las cuentas con privilegios de administración no son cuentas de la aplicación.

## Datos de demostración

10 usuarios; 30 clientes; 45 equipos; 60 órdenes; 45 diagnósticos; 40 reparaciones;
30 repuestos; 3 bodegas; 90 pares de inventario; 8 proveedores; 20 compras;
118 movimientos (48 entradas y 70 salidas); 30 facturas; 46 pagos.
Incluye 15 facturas pagadas, 8 parciales, 7 sin pagos, 4 compras pendientes,
5 reparaciones sin repuestos y 15 entregas. Cliente 30 no tiene órdenes.
El equipo TC-SERIE-0001 tiene al menos cuatro órdenes. Las fechas se calculan
con relación a la fecha UTC en que se ejecuta el script.

Usuarios demo01 ADMIN, demo02/03 RECEPCION, demo04/05/06 TECNICO,
demo07/08 BODEGA, demo09/10 CAJA. Contraseña de prueba: `TechCare2026!`.
PasswordHash contiene `$pbkdf2-sha256$600000$<salt_base64>$<clave_base64>`;
el backend debe verificar PBKDF2-HMAC-SHA256 y comparar en tiempo constante.
Los salts del fixture son deterministas para reproducibilidad; en registros reales
usar salts aleatorios. No se usan contraseñas en texto plano ni SHA256 simple.

## Diagramas y documentación

- `TechCare_Diseno_y_Normalizacion.pdf`: decisiones, relaciones, diagramas y 1FN/2FN/3FN.
- `diagramas/TechCare_Modelo.drawio`: seis páginas editables, una por área.
- `diagramas/01_ER_Seguridad.svg` ... `06_ER_Caja.svg`: diagramas vectoriales ampliables.
- `diagramas/Modelo_Completo.mmd`: ER físico completo en Mermaid, las 35 tablas y todas las FK.
- `modelo.json`: especificación de tablas, columnas, claves, índices y relaciones.
- Los diagramas de estados y procesos se incluyen como SVG y en el PDF.

Los reportes 1, 2, 3, 4, 5, 8, 9, 10 y 12 recorren seis o más tablas de la
implementación (incluyendo tablas internas de las vistas cuando corresponde).
LEFT JOIN conserva procesos incompletos. R12 devuelve una fila por orden y listas JSON
independientes para estados, repuestos/movimientos y pagos; evita repuestos x pagos.
R10 repite encabezado por pago: no sumar Total sobre esas filas. Usar vFacturaSaldo.

## Alcance de la validación entregada

Se verifica correspondencia estructural de PK/FK/columnas/diagramas, cantidades de
objetos y los datos generados. Se incluyen aserciones SQL para kardex, saldos,
rollback, roles, doble recepción, factura única, entrega y precios históricos.
Esta sesión no tiene una instancia de SQL Server: la ejecución real y la evidencia
de esos casos se obtienen al ejecutar 04_Pruebas_Integridad.sql en su instancia.


## Actualización: triggers agrupados

Se pasó de 28 a 16 triggers. Doce tablas tenían un trigger de validación y otro de
protección histórica: ahora cada tabla tiene un único trigger con ambos controles.
Las validaciones originales, las restricciones, los procedimientos y los permisos
del backend se conservan. Las tablas y relaciones del modelo no cambian.

En una base nueva, ejecute los scripts 01, 02, 03 y 04 del paquete actualizado.
Si ya tiene la base anterior, ejecute `05_Actualizar_Triggers.sql` y luego
`04_Pruebas_Integridad.sql`. El script 05 actualiza las definiciones en una
transacción y conserva los datos. No vuelva a ejecutar el script de datos de prueba.

Algunas operaciones inválidas pueden ser rechazadas primero por una FK o CHECK
antes de llegar al trigger AFTER. Ambos mecanismos conservan la integridad;
el mensaje SQL concreto puede variar frente a la versión con INSTEAD OF.

Documentos para el equipo:

- `GUIA_TRIGGERS.md`: definición, inserted/deleted, ejemplo reversible y los 16 objetos.
- `GUIA_GITHUB.md`: publicación privada con GitHub Desktop y trabajo por ramas.
- `CAMBIOS.md`: correspondencia entre los 28 triggers anteriores y los 16 actuales.

La ejecución real sigue pendiente en su instancia de SQL Server. El archivo de
validación informa revisión estática, no pruebas de motor ya realizadas.
