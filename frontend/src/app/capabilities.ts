/**
 * Capacidades de acceso, clientes, equipos, órdenes y servicio técnico.
 * Las rutas disponibles requieren sesión y permisos del servidor.
 * El inventario general y la caja conservan su estado pendiente.
 */

export type EstadoCapacidad = "disponible" | "incompleta" | "ausente";

export interface OperacionApi {
  id: string;
  modulo: string;
  /** Operacion de negocio en lenguaje del taller. */
  operacion: string;
  /** Metodo HTTP real, o "Sin endpoint". */
  metodo: string;
  /** Ruta real, o la ruta propuesta que requiere el backend. */
  ruta: string;
  /** DTO/entrada real. */
  entrada: string;
  /** DTO de respuesta real. */
  respuesta: string;
  /** Roles autorizados para la operación. */
  roles: string;
  estado: EstadoCapacidad;
  /** Proceso SQL de referencia cuando no hay endpoint. */
  procedimiento?: string;
  nota?: string;
}

export const OPERACIONES: OperacionApi[] = [
  // ---- Sesión y autenticación ----
  {
    "id": "auth.login",
    "modulo": "Acceso",
    "operacion": "Iniciar sesión del personal",
    "metodo": "POST",
    "ruta": "/api/auth/login",
    "entrada": "nombreUsuario, contrasena",
    "respuesta": "usuario + roles[]",
    "roles": "Todos",
    "estado": "disponible",
    "procedimiento": "spConsultarAcceso",
    "nota": "Contraseña verificada con PBKDF2-HMAC-SHA256 en el servidor; el hash no se devuelve."
  },
  {
    "id": "auth.sesion",
    "modulo": "Acceso",
    "operacion": "Consultar sesión actual",
    "metodo": "GET",
    "ruta": "/api/auth/sesion",
    "entrada": "Cookie de sesión",
    "respuesta": "usuario + roles[]",
    "roles": "Todos",
    "estado": "disponible",
    "nota": "La sesión se recupera al recargar; sin sesión válida responde 401."
  },
  {
    "id": "auth.logout",
    "modulo": "Acceso",
    "operacion": "Cerrar sesión",
    "metodo": "POST",
    "ruta": "/api/auth/logout",
    "entrada": "Cookie + CSRF",
    "respuesta": "Sesión cerrada",
    "roles": "Todos",
    "estado": "disponible",
    "nota": "Invalida la sesión del servidor y elimina la cookie."
  },
  {
    "id": "auth.csrf",
    "modulo": "Acceso",
    "operacion": "Preparar protección de solicitudes",
    "metodo": "GET",
    "ruta": "/api/auth/csrf",
    "entrada": "-",
    "respuesta": "headerName, token",
    "roles": "Todos",
    "estado": "disponible"
  },

  // ---- Dashboard ----
  {
    id: "dashboard.resumen",
    modulo: "Inicio",
    operacion: "Seis metricas del taller",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/dashboard)",
    entrada: "-",
    respuesta: "OrdenesAbiertas, EnDiagnostico, EnReparacion, Listas, FacturasPendientes, StockBajo",
    roles: "Todos (segun rol)",
    estado: "ausente",
    procedimiento: "vDashboard",
    nota: "Las metricas ya estan calculadas por la vista vDashboard. No recalcular sobre una pagina de resultados.",
  },
  {
    id: "dashboard.actividad",
    modulo: "Inicio",
    operacion: "Actividad reciente",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/dashboard/actividad)",
    entrada: "limite",
    respuesta: "eventos de HistorialEstadoOrden / movimientos",
    roles: "Todos",
    estado: "ausente",
    procedimiento: "HistorialEstadoOrden, MovimientoInventario",
  },

  // ---- Clientes ----
  {
    id: "clientes.listar",
    modulo: "Clientes",
    operacion: "Listar clientes",
    metodo: "GET",
    ruta: "/api/clientes",
    entrada: "-",
    respuesta: "Cliente[]",
    roles: "RECEPCION, TECNICO, CAJA, ADMIN",
    estado: "incompleta",
    nota: "Devuelve el conjunto completo sin paginacion ni filtros de servidor; el frontend pagina/filtra en cliente sobre ese conjunto.",
  },
  {
    id: "clientes.consultar",
    modulo: "Clientes",
    operacion: "Consultar cliente",
    metodo: "GET",
    ruta: "/api/clientes/{id}",
    entrada: "id",
    respuesta: "Cliente",
    roles: "RECEPCION, TECNICO, CAJA, ADMIN",
    estado: "disponible",
  },
  {
    id: "clientes.crear",
    modulo: "Clientes",
    operacion: "Registrar cliente",
    metodo: "POST",
    ruta: "/api/clientes",
    entrada: "ClienteDatos",
    respuesta: "Cliente (201)",
    roles: "RECEPCION, ADMIN",
    estado: "disponible",
    nota: "Valida tipo de cliente y NIT unico. El email no es obligatorio.",
  },
  {
    id: "clientes.actualizar",
    modulo: "Clientes",
    operacion: "Actualizar / activar / desactivar cliente",
    metodo: "PUT",
    ruta: "/api/clientes/{id}",
    entrada: "ClienteDatos",
    respuesta: "Cliente",
    roles: "RECEPCION, ADMIN",
    estado: "disponible",
    nota: "No hay DELETE: la desactivacion es Activo=false.",
  },

  // ---- Equipos y sus catálogos ----
  {
    "id": "equipos.listar",
    "modulo": "Equipos",
    "operacion": "Buscar equipos por serie / cliente",
    "metodo": "GET",
    "ruta": "/api/equipos",
    "entrada": "clienteId?, serie?, activo?",
    "respuesta": "Equipo[]",
    "roles": "RECEPCION, TECNICO, ADMIN",
    "estado": "disponible",
    "procedimiento": "spListarEquipos"
  },
  {
    "id": "equipos.consultar",
    "modulo": "Equipos",
    "operacion": "Consultar equipo",
    "metodo": "GET",
    "ruta": "/api/equipos/{id}",
    "entrada": "id",
    "respuesta": "Equipo",
    "roles": "RECEPCION, TECNICO, ADMIN",
    "estado": "disponible",
    "procedimiento": "spConsultarEquipo"
  },
  {
    "id": "equipos.crear",
    "modulo": "Equipos",
    "operacion": "Registrar equipo",
    "metodo": "POST",
    "ruta": "/api/equipos",
    "entrada": "EquipoDatos",
    "respuesta": "Equipo (201)",
    "roles": "RECEPCION, ADMIN",
    "estado": "disponible",
    "procedimiento": "spRegistrarEquipo"
  },
  {
    "id": "equipos.actualizar",
    "modulo": "Equipos",
    "operacion": "Actualizar / activar / desactivar equipo",
    "metodo": "PUT",
    "ruta": "/api/equipos/{id}",
    "entrada": "id, EquipoDatos",
    "respuesta": "Equipo",
    "roles": "RECEPCION, ADMIN",
    "estado": "disponible",
    "procedimiento": "spActualizarEquipo",
    "nota": "Con órdenes se conserva propietario, serie y modelo; descripción y Activo pueden actualizarse."
  },
  {
    "id": "equipos.historial",
    "modulo": "Equipos",
    "operacion": "Consultar historial de un equipo",
    "metodo": "GET",
    "ruta": "/api/equipos/{id}/historial",
    "entrada": "id",
    "respuesta": "HistorialEquipo[]",
    "roles": "RECEPCION, TECNICO, ADMIN",
    "estado": "disponible",
    "procedimiento": "spHistorialEquipoAcceso"
  },
  {
    "id": "catalogos.tiposEquipos",
    "modulo": "Catalogos",
    "operacion": "Consultar tipos de equipo",
    "metodo": "GET",
    "ruta": "/api/catalogos/tipos-equipos",
    "entrada": "-",
    "respuesta": "TipoEquipo[]",
    "roles": "RECEPCION, TECNICO, ADMIN",
    "estado": "disponible",
    "procedimiento": "spListarTiposEquipo"
  },
  {
    "id": "catalogos.marcas",
    "modulo": "Catalogos",
    "operacion": "Consultar marcas",
    "metodo": "GET",
    "ruta": "/api/catalogos/marcas",
    "entrada": "-",
    "respuesta": "Marca[]",
    "roles": "RECEPCION, TECNICO, ADMIN",
    "estado": "disponible",
    "procedimiento": "spListarMarcas"
  },
  {
    "id": "catalogos.modelosEquipos",
    "modulo": "Catalogos",
    "operacion": "Consultar modelos",
    "metodo": "GET",
    "ruta": "/api/catalogos/modelos-equipos",
    "entrada": "marcaId?, tipoEquipoId?",
    "respuesta": "ModeloEquipo[]",
    "roles": "RECEPCION, TECNICO, ADMIN",
    "estado": "disponible",
    "procedimiento": "spListarModelosEquipo"
  },

  // ---- Ordenes ----
  {
    id: "ordenes.listar", modulo: "Ordenes", operacion: "Listar y filtrar órdenes",
    metodo: "GET", ruta: "/api/ordenes", entrada: "buscar?, estado?, prioridad?, tecnicoId?, desde?, hasta?",
    respuesta: "Orden[]", roles: "ADMIN, RECEPCION, TECNICO (sus órdenes), CAJA", estado: "disponible",
    procedimiento: "spListarOrdenes", nota: "El cliente se obtiene del equipo. SQL filtra el acceso por usuario.",
  },
  {
    id: "ordenes.crear", modulo: "Ordenes", operacion: "Registrar ingreso",
    metodo: "POST", ruta: "/api/ordenes", entrada: "equipoId, problema, prioridad, fechaEstimada?, observaciones?",
    respuesta: "Orden", roles: "ADMIN, RECEPCION", estado: "disponible", procedimiento: "spRegistrarOrden",
    nota: "Número y actor se resuelven en el servidor; el trigger crea el historial inicial.",
  },
  {
    id: "ordenes.expediente", modulo: "Ordenes", operacion: "Consultar expediente de la orden",
    metodo: "GET", ruta: "/api/ordenes/{id}", entrada: "id", respuesta: "Orden",
    roles: "ADMIN, RECEPCION, TECNICO (sus órdenes), CAJA", estado: "incompleta", procedimiento: "spConsultarOrden",
    nota: "Recepción, diagnóstico, reparación y consumos conectados. Cobros y entrega pendientes.",
  },
  {
    id: "ordenes.asignar", modulo: "Ordenes", operacion: "Asignar o reasignar técnico",
    metodo: "PUT", ruta: "/api/ordenes/{id}/tecnico", entrada: "tecnicoId, tecnicoAnteriorId, observacion?",
    respuesta: "Orden", roles: "ADMIN, RECEPCION", estado: "disponible", procedimiento: "spAsignarTecnicoOrden",
    nota: "Antes del diagnóstico. Conserva cada asignación y detecta pantallas desactualizadas.",
  },
  {
    id: "ordenes.historial", modulo: "Ordenes", operacion: "Consultar historial",
    metodo: "GET", ruta: "/api/ordenes/{id}/historial", entrada: "id", respuesta: "EventoOrden[]",
    roles: "ADMIN, RECEPCION, TECNICO (sus órdenes), CAJA", estado: "disponible", procedimiento: "spHistorialOrden",
  },
  {
    id: "ordenes.cancelar", modulo: "Ordenes", operacion: "Cancelar orden",
    metodo: "POST", ruta: "/api/ordenes/{id}/cancelacion", entrada: "motivo", respuesta: "Orden",
    roles: "ADMIN, RECEPCION", estado: "disponible", procedimiento: "spCancelarOrden",
    nota: "Exige motivo y transición permitida. Conserva la orden y su historial.",
  },
  {
    id: "ordenes.catalogos", modulo: "Ordenes", operacion: "Consultar estados y prioridades",
    metodo: "GET", ruta: "/api/ordenes/catalogos/{estados|prioridades}", entrada: "catálogo",
    respuesta: "CatalogoOrden[]", roles: "ADMIN, RECEPCION, TECNICO, CAJA", estado: "disponible", procedimiento: "spCatalogosOrden",
  },
  {
    id: "ordenes.tecnicos", modulo: "Ordenes", operacion: "Consultar técnicos activos",
    metodo: "GET", ruta: "/api/ordenes/catalogos/tecnicos", entrada: "-", respuesta: "TecnicoOrden[]",
    roles: "ADMIN, RECEPCION", estado: "disponible", procedimiento: "spCatalogosOrden",
  },

  // ---- Diagnostico / reparacion ----
  {
    id: "diagnostico.iniciar", modulo: "Servicio tecnico", operacion: "Iniciar revisión del equipo",
    metodo: "POST", ruta: "/api/ordenes/{id}/diagnostico/inicio", entrada: "-", respuesta: "Orden",
    roles: "TECNICO asignado", estado: "disponible", procedimiento: "spIniciarDiagnosticoOrden",
  },
  {
    id: "diagnostico.registrar",
    modulo: "Servicio tecnico",
    operacion: "Registrar diagnostico",
    metodo: "POST",
    ruta: "/api/ordenes/{id}/diagnostico",
    entrada: "descripcion, costoEstimado",
    respuesta: "Orden (201)",
    roles: "TECNICO asignado",
    estado: "disponible",
    procedimiento: "spRegistrarDiagnosticoOrden",
    nota: "Termina en ESPERANDO_AUTORIZACION. El técnico proviene de la sesión y debe ser el asignado.",
  },
  {
    id: "reparacion.iniciar",
    modulo: "Servicio tecnico",
    operacion: "Iniciar reparacion",
    metodo: "POST",
    ruta: "/api/ordenes/{id}/reparacion",
    entrada: "descripcionTrabajo, costoManoObra, autorizacion",
    respuesta: "Orden (201)",
    roles: "TECNICO asignado",
    estado: "disponible",
    procedimiento: "spIniciarReparacionOrden",
    nota: "Exige diagnostico previo y constancia de autorizacion del cliente (se documenta en la observacion del cambio de estado).",
  },
  {
    id: "reparacion.actividad",
    modulo: "Servicio tecnico",
    operacion: "Registrar actividad",
    metodo: "POST",
    ruta: "/api/ordenes/{id}/actividades",
    entrada: "actividadId, observacion?",
    respuesta: "Orden",
    roles: "TECNICO asignado",
    estado: "disponible",
    procedimiento: "spAgregarActividadOrden",
  },
  {
    id: "reparacion.consumir",
    modulo: "Servicio tecnico",
    operacion: "Consumir repuesto",
    metodo: "POST",
    ruta: "/api/ordenes/{id}/repuestos",
    entrada: "bodegaId, repuestoId, cantidad, precioUnitarioEsperado",
    respuesta: "Orden",
    roles: "TECNICO asignado",
    estado: "disponible",
    procedimiento: "spUsarRepuestoOrden",
    nota: "Validacion + consumo + movimiento de salida en una sola transaccion. El frontend no crea movimiento ni edita existencias.",
  },
  {
    id: "reparacion.cerrar",
    modulo: "Servicio tecnico",
    operacion: "Finalizar reparacion",
    metodo: "POST",
    ruta: "/api/ordenes/{id}/reparacion/cierre",
    entrada: "-",
    respuesta: "Orden",
    roles: "TECNICO asignado",
    estado: "disponible",
    procedimiento: "spFinalizarReparacionOrden",
    nota: "Termina la reparacion y deja la orden en LISTO.",
  },

  {
    id: "servicio.actividades", modulo: "Servicio tecnico", operacion: "Consultar actividades realizadas",
    metodo: "GET", ruta: "/api/ordenes/{id}/actividades", entrada: "id", respuesta: "ActividadRealizada[]",
    roles: "ADMIN, RECEPCION, TECNICO (sus órdenes), CAJA", estado: "disponible", procedimiento: "spActividadesOrden",
  },
  {
    id: "servicio.repuestos", modulo: "Servicio tecnico", operacion: "Consultar repuestos utilizados y su salida",
    metodo: "GET", ruta: "/api/ordenes/{id}/repuestos", entrada: "id", respuesta: "RepuestoUsado[]",
    roles: "ADMIN, RECEPCION, TECNICO (sus órdenes), CAJA", estado: "disponible", procedimiento: "spRepuestosOrden",
  },
  {
    id: "servicio.catalogoActividades", modulo: "Servicio tecnico", operacion: "Consultar catálogo de actividades",
    metodo: "GET", ruta: "/api/ordenes/{id}/catalogos/actividades", entrada: "id", respuesta: "ActividadDisponible[]",
    roles: "ADMIN, RECEPCION, TECNICO (sus órdenes), CAJA", estado: "disponible", procedimiento: "spCatalogoActividadesOrden",
  },
  {
    id: "servicio.catalogoRepuestos", modulo: "Servicio tecnico", operacion: "Consultar existencias para una reparación propia",
    metodo: "GET", ruta: "/api/ordenes/{id}/catalogos/repuestos", entrada: "id", respuesta: "RepuestoDisponible[]",
    roles: "TECNICO asignado", estado: "disponible", procedimiento: "spCatalogoRepuestosOrden",
  },

  // ---- Inventario / repuestos / bodegas ----
  {
    id: "inventario.consultar",
    modulo: "Inventario",
    operacion: "Existencias por bodega/repuesto",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/inventario)",
    entrada: "bodegaId, categoriaId, texto",
    respuesta: "existencia, minimo, condicion",
    roles: "BODEGA, ADMIN",
    estado: "ausente",
    procedimiento: "vInventario",
    nota: "El stock se obtiene del kardex. No debe existir un campo editable de existencia.",
  },
  {
    id: "inventario.movimientos",
    modulo: "Inventario",
    operacion: "Kardex / movimientos",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/inventario/movimientos)",
    entrada: "bodegaId, fechas",
    respuesta: "movimientos con origen y existencia resultante",
    roles: "BODEGA, ADMIN",
    estado: "ausente",
    procedimiento: "vMovimientoInventario",
  },
  {
    id: "repuestos.catalogo",
    modulo: "Repuestos",
    operacion: "Catalogo de repuestos",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/repuestos)",
    entrada: "categoriaId, texto, activo",
    respuesta: "Repuesto[]",
    roles: "BODEGA, ADMIN",
    estado: "ausente",
    nota: "Editar costo/precio no altera consumos ni facturas anteriores (AuditoriaPrecioRepuesto).",
  },
  {
    id: "bodegas.listar",
    modulo: "Bodegas",
    operacion: "Administrar bodegas",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/bodegas)",
    entrada: "Datos",
    respuesta: "Bodega[]",
    roles: "ADMIN, BODEGA",
    estado: "ausente",
  },

  // ---- Proveedores / compras ----
  {
    id: "proveedores.listar",
    modulo: "Proveedores",
    operacion: "Administrar proveedores",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/proveedores)",
    entrada: "Datos, repuestos asociados",
    respuesta: "Proveedor[]",
    roles: "BODEGA, ADMIN",
    estado: "ausente",
    nota: "ProveedorRepuesto conserva el catalogo ofrecido por cada proveedor.",
  },
  {
    id: "compras.listar",
    modulo: "Compras",
    operacion: "Listar compras por proveedor/fecha/estado",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/compras)",
    entrada: "proveedorId, estado, fechas",
    respuesta: "Compra[] con detalle",
    roles: "BODEGA, ADMIN",
    estado: "ausente",
  },
  {
    id: "compras.registrar",
    modulo: "Compras",
    operacion: "Registrar compra",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/compras)",
    entrada: "NumeroCompra, ProveedorID, Detalle[]",
    respuesta: "CompraID",
    roles: "BODEGA",
    estado: "ausente",
    procedimiento: "spRegistrarCompra",
    nota: "Crea encabezado y lineas; NO aumenta stock.",
  },
  {
    id: "compras.recibir",
    modulo: "Compras",
    operacion: "Recibir compra (una sola vez, completa)",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/compras/{id}/recibir)",
    entrada: "-",
    respuesta: "ok",
    roles: "BODEGA",
    estado: "ausente",
    procedimiento: "spRecibirCompra",
    nota: "Genera todas las entradas y cambia el estado en una transaccion. Una compra recibida no se recibe de nuevo.",
  },
  {
    id: "compras.anular",
    modulo: "Compras",
    operacion: "Anular compra pendiente",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/compras/{id}/anular)",
    entrada: "Motivo",
    respuesta: "ok",
    roles: "BODEGA",
    estado: "ausente",
    procedimiento: "spAnularCompra",
  },

  // ---- Facturacion / pagos / entrega ----
  {
    id: "facturas.listar",
    modulo: "Facturacion",
    operacion: "Listar facturas y saldos",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/facturas)",
    entrada: "estado, clienteId",
    respuesta: "vFacturaSaldo[]",
    roles: "CAJA, ADMIN",
    estado: "ausente",
    procedimiento: "vFacturaSaldo",
    nota: "Subtotal, Impuesto, Total, Pagado, Saldo y EstadoPago se calculan en la vista; no se capturan.",
  },
  {
    id: "facturas.emitir",
    modulo: "Facturacion",
    operacion: "Emitir factura",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/ordenes/{id}/factura)",
    entrada: "NumeroFactura, TasaImpuesto",
    respuesta: "FacturaID",
    roles: "CAJA",
    estado: "ausente",
    procedimiento: "spGenerarFactura",
    nota: "Requiere orden LISTO y reparacion TERMINADA. Cero o una factura por orden. Conserva datos fiscales del cliente.",
  },
  {
    id: "pagos.registrar",
    modulo: "Facturacion",
    operacion: "Registrar pago",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/facturas/{id}/pagos)",
    entrada: "MetodoPagoID, Monto, Referencia",
    respuesta: "ok",
    roles: "CAJA",
    estado: "ausente",
    procedimiento: "spRegistrarPago",
    nota: "Valida monto contra saldo en la transaccion. Multiples pagos por factura.",
  },
  {
    id: "facturas.anular",
    modulo: "Facturacion",
    operacion: "Anular factura",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/facturas/{id}/anular)",
    entrada: "-",
    respuesta: "ok",
    roles: "CAJA",
    estado: "ausente",
    procedimiento: "spAnularFactura",
    nota: "Solo sin pagos ni entrega.",
  },
  {
    id: "entrega.registrar",
    modulo: "Entrega",
    operacion: "Registrar entrega y cierre",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/ordenes/{id}/entrega)",
    entrada: "NombreRecibe, DocumentoRecibe, Observaciones",
    respuesta: "ok",
    roles: "RECEPCION",
    estado: "ausente",
    procedimiento: "spEntregarOrden",
    nota: "Requiere orden LISTO, reparacion TERMINADA, factura EMITIDA y saldo cero.",
  },

  // ---- Reportes ----
  {
    id: "reportes.consultar",
    modulo: "Reportes",
    operacion: "Doce reportes de la consigna",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/reportes/{r01..r12})",
    entrada: "filtros por reporte",
    respuesta: "filas del reporte",
    roles: "Segun rol",
    estado: "ausente",
    procedimiento: "03_Reportes.sql (R01..R12)",
    nota: "Los datos deben venir de consultas del servidor. No construir JOIN ni agregaciones en el navegador.",
  },

  // ---- Administracion ----
  {
    id: "admin.usuarios",
    modulo: "Administracion",
    operacion: "Consultar cuentas y sus roles",
    metodo: "GET",
    ruta: "/api/admin/usuarios",
    entrada: "Sesión ADMIN",
    respuesta: "UsuarioResumen[]",
    roles: "ADMIN",
    estado: "disponible",
    procedimiento: "spListarUsuarios",
    nota: "La respuesta usa un DTO sin contraseñas ni hashes.",
  },
  {
    id: "admin.usuario.crear", modulo: "Administracion", operacion: "Registrar usuario y asignar roles",
    metodo: "POST", ruta: "/api/admin/usuarios", entrada: "nombreUsuario, contrasena, roles[], empleadoId o empleadoNuevo",
    respuesta: "UsuarioResumen", roles: "ADMIN", estado: "disponible", procedimiento: "spRegistrarUsuario",
    nota: "Java genera PBKDF2 con sal aleatoria. SQL registra empleado, cuenta y roles en una transacción.",
  },
  {
    id: "admin.usuario.consultar", modulo: "Administracion", operacion: "Consultar una cuenta",
    metodo: "GET", ruta: "/api/admin/usuarios/{id}", entrada: "ID", respuesta: "UsuarioResumen",
    roles: "ADMIN", estado: "disponible", procedimiento: "spListarUsuarios",
  },
  {
    id: "admin.roles", modulo: "Administracion", operacion: "Consultar roles disponibles",
    metodo: "GET", ruta: "/api/admin/roles", entrada: "-", respuesta: "RolAcceso[]",
    roles: "ADMIN", estado: "disponible", procedimiento: "spListarRolesAcceso",
  },
  {
    id: "admin.empleados", modulo: "Administracion", operacion: "Consultar empleados activos sin cuenta",
    metodo: "GET", ruta: "/api/admin/empleados-disponibles", entrada: "-", respuesta: "EmpleadoDisponible[]",
    roles: "ADMIN", estado: "disponible", procedimiento: "spListarEmpleadosDisponibles",
  },
  {
    id: "admin.catalogos",
    modulo: "Administracion",
    operacion: "Catalogos (marcas, modelos, actividades, categorias)",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/admin/catalogos)",
    entrada: "Datos",
    respuesta: "Catalogos[]",
    roles: "ADMIN",
    estado: "ausente",
  },
];

export function operacion(id: string): OperacionApi | undefined {
  return OPERACIONES.find((o) => o.id === id);
}

export function operacionesDeModulo(modulo: string): OperacionApi[] {
  return OPERACIONES.filter((o) => o.modulo === modulo);
}

export function esDisponible(id: string): boolean {
  const op = operacion(id);
  return op?.estado === "disponible" || op?.estado === "incompleta";
}

export const ETIQUETA_ESTADO: Record<EstadoCapacidad, string> = {
  disponible: "Conectado",
  incompleta: "Parcial",
  ausente: "Pendiente de API",
};
