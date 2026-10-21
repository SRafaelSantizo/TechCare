# Servicio técnico: del diagnóstico a LISTO

Continuación de la recepción de Órdenes del commit `2b905f3`. El técnico asignado
inicia la revisión, registra el diagnóstico y la mano de obra estimada, documenta
la autorización e inicia la reparación. Después registra actividades y repuestos
utilizados y finaliza el servicio en LISTO.

## Instalación

1. Guardar `21_Servicio_Tecnico_API.patch` en la raíz de TechCare, junto a `backend` y `frontend`.
2. En la terminal de IntelliJ, ubicada en esa raíz, ejecutar:

   ```bash
   git apply --check 21_Servicio_Tecnico_API.patch
   git apply 21_Servicio_Tecnico_API.patch
   ```

   El primer comando comprueba compatibilidad sin modificar archivos. Si muestra
   un conflicto, revisar esa salida antes de aplicar; no forzar la sustitución.
   El paquete se aplica una sola vez sobre la integración de Órdenes existente.

3. En SSMS ejecutar completo `19_Servicio_Tecnico_Procedimientos.sql` en la
   instancia habitual de TechCare. Es repetible y conserva los datos.
4. En la base de desarrollo, sin transacciones abiertas ni escrituras concurrentes,
   ejecutar `20_Pruebas_Servicio_Tecnico.sql`. Contiene 40 casos, revierte sus datos
   y muestra PASS/FAIL. Los huecos en identidades son normales.
5. Reiniciar el backend desde IntelliJ y abrir el frontend como de costumbre.
   Para comprobar la compilación desde la raíz:

   ```bash
   npm --prefix frontend run build
   ```

No se vuelven a ejecutar 01, 02 ni 16 si ya están instalados. Cada integrante
con base propia ejecuta el 19 en esa base. Una instalación nueva aplica primero
01, 02, 06, 08, 11, 13 y 16. Se conservan POM, credenciales y configuración local.

## Recorrido desde la interfaz

1. Con ADMIN o RECEPCION, registrar una orden y asignar un técnico activo.
2. Entrar con ese técnico, abrir Órdenes y luego el expediente asignado.
3. En Diagnóstico, pulsar **Iniciar diagnóstico**: pasa a DIAGNOSTICO.
4. Usar **Registrar diagnóstico y estimación**, describir la falla encontrada y
   anotar la mano de obra estimada, por ejemplo Q125.50. Revisar y confirmar:
   pasa a ESPERANDO_AUTORIZACION.
5. En Reparación, usar **Autorizar e iniciar reparación**. Revisar el trabajo y
   la mano de obra acordada. Documentar quién autorizó, cuándo y por qué medio.
   Al confirmar queda en REPARACION y la autorización aparece en Historial.
6. Usar **Registrar actividad** con el trabajo realizado o su observación.
7. Si hubo consumos, abrir Repuestos → **Registrar repuesto utilizado**. Elegir
   repuesto, bodega y cantidad; revisar precio unitario y confirmar. Aparecen el
   consumo y su movimiento de salida. También se permite solo mano de obra.
8. Verificar tareas y consumos. En Reparación, usar **Finalizar reparación** y
   confirmar: reparación TERMINADA y orden LISTO.
9. Revisar Historial y probar que otro técnico no acceda a la orden ajena.

demo04, demo05 y demo06 tienen rol TECNICO; también sirven cuentas nuevas creadas
desde Administración. El técnico debe ser el asignado. Entrar únicamente como
ADMIN permite consultar, pero no sustituye al responsable del trabajo. Un ADMIN
con rol TECNICO explícito puede ser asignado y trabajar sus propias órdenes.

## Reglas y límites

- Usuario y fecha se obtienen de sesión/servidor. SQL valida la asignación y el
  rol, incluso al llamar la API directamente. No hay endpoint de estado libre.
- ADMIN, RECEPCION y CAJA consultan; TECNICO consulta sus órdenes y trabaja las
  propias. BODEGA conserva su restricción de acceso a Órdenes.
- Se conserva el diagnóstico y la mano de obra acordada al iniciar. Las tareas
  documentan el trabajo realizado; cada actividad se agrega una vez.
- La autorización es una constancia escrita por el técnico; no es una solicitud
  enviada al cliente ni una firma electrónica.
- Consumo y salida se registran en la misma transacción. Stock insuficiente
  devuelve 409 y revierte la operación. El precio mostrado se compara con el
  catálogo; si cambió, se exige actualizar y revisar antes de confirmar.
- El servidor elige el precio y conserva su valor histórico. Cada importe de
  línea se calcula en SQL. La consulta de existencias del técnico está acotada
  al expediente propio y no habilita el módulo general de Inventario.
- Tras finalizar no se agregan actividades ni consumos ni se reabre el trabajo.
- Ante error de red al consumir, actualizar y revisar las líneas utilizadas
  antes de registrar nuevamente. No se reintentan automáticamente escrituras
  que pudieron haberse ejecutado.

## API agregada

Todas las rutas comienzan con `/api/ordenes/{id}`. Las escrituras requieren cookie
de sesión y CSRF y devuelven la Orden actualizada.

| Método | Terminación | Entrada o respuesta |
|---|---|---|
| POST | `/diagnostico/inicio` | Sin cuerpo; inicia revisión |
| POST | `/diagnostico` | `descripcion`, `costoEstimado`; 201 |
| POST | `/reparacion` | `descripcionTrabajo`, `costoManoObra`, `autorizacion`; 201 |
| GET | `/actividades` | Tareas, fecha y observación |
| POST | `/actividades` | `actividadId`, `observacion` opcional |
| GET | `/repuestos` | Consumos, precio histórico y salida |
| POST | `/repuestos` | `bodegaId`, `repuestoId`, `cantidad`, `precioUnitarioEsperado` |
| GET | `/catalogos/actividades` | Actividades activas |
| GET | `/catalogos/repuestos` | Existencias para el técnico asignado |
| POST | `/reparacion/cierre` | Sin cuerpo; finaliza y deja LISTO |

Se reutilizan los procedimientos originales. El 19 agrega controles y consultas
sin modificar tablas, triggers ni el maestro 01. Se conserva el rol `techcare_app`.

## Validación

- TypeScript y Vite: compilación correcta del frontend.
- Recorrido de pantallas verificado con API simulada: diagnóstico, autorización,
  actividades, consumo, conflicto de stock, cierre en LISTO y consulta desde
  Recepción. También se revisó el ancho móvil y la ausencia de errores JavaScript.
  Se corrigió el foco del diálogo para que escribir un costo no mueva el cursor
  a la descripción.
- Backend: 130 pruebas ejecutadas sin fallos ni omisiones, incluidas 30 nuevas.
  Las pruebas HTTP usan JDBC simulado: verifican rutas, sesión, CSRF, validación,
  parámetros y respuestas; no ejecutan el motor de base de datos.
- El script 20 incluye 40 escenarios SQL de permisos, estados, autorización,
  duplicados, stock, rollback de datos de prueba y precios históricos. Su
  ejecución real queda pendiente en la instancia del equipo: aquí no hay
  SQL Server conectado. No sustituye una prueba de sesiones concurrentes.

La siguiente integración es Factura → pagos/abonos → entrega con saldo cero.
Este paquete llega a LISTO; Inventario general, Compras y Caja siguen pendientes.

Después de ejecutar los scripts y probar el flujo, guardar en la rama actual:

```bash
git add .
git commit -m "Se integra diagnostico, reparacion y consumo de repuestos"
git push
```
