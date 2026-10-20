/**
 * Capacidades verificadas en los controladores de Clientes, Equipos y catálogos.
 * Las rutas disponibles requieren sesión y permisos del servidor.
 * Los procesos de órdenes, inventario y caja conservan su estado pendiente.
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
    "procedimiento": "spHistorialEquipo"
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
    id: "ordenes.listar",
    modulo: "Ordenes",
    operacion: "Listar y filtrar ordenes",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/ordenes)",
    entrada: "estado, prioridad, tecnico, fechas, texto",
    respuesta: "OrdenResumen[]",
    roles: "Todos",
    estado: "ausente",
    procedimiento: "vOrdenResumen",
    nota: "Orden no repite ClienteID: el propietario se obtiene via Equipo.",
  },
  {
    id: "ordenes.crear",
    modulo: "Ordenes",
    operacion: "Registrar ingreso (crear orden)",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/ordenes)",
    entrada: "NumeroOrden, EquipoID, Problema, Prioridad, FechaEstimada, Observaciones",
    respuesta: "OrdenID",
    roles: "RECEPCION",
    estado: "ausente",
    procedimiento: "spCrearOrden",
    nota: "spCrearOrden crea la orden y el historial inicial en RECIBIDO. El NumeroOrden lo genera/valida el servidor.",
  },
  {
    id: "ordenes.expediente",
    modulo: "Ordenes",
    operacion: "Expediente completo de la orden",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/ordenes/{id})",
    entrada: "id",
    respuesta: "orden + equipo + cliente + diagnostico + reparacion + repuestos + factura + entrega + historial",
    roles: "Todos",
    estado: "ausente",
    procedimiento: "vOrdenResumen, vConsumoRepuesto, vFacturaSaldo, HistorialEstadoOrden",
    nota: "La ausencia de diagnostico/reparacion/factura es un estado valido, no un error.",
  },
  {
    id: "ordenes.cambiarEstado",
    modulo: "Ordenes",
    operacion: "Cambio permitido o cancelacion",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/ordenes/{id}/estado)",
    entrada: "EstadoNuevo, Observacion",
    respuesta: "ok",
    roles: "TECNICO, RECEPCION",
    estado: "ausente",
    procedimiento: "spCambiarEstadoOrden",
    nota: "Valida TransicionEstadoOrden y escribe HistorialEstadoOrden. El frontend no debe duplicar el cambio de estado.",
  },

  // ---- Diagnostico / reparacion ----
  {
    id: "diagnostico.registrar",
    modulo: "Servicio tecnico",
    operacion: "Registrar diagnostico",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/ordenes/{id}/diagnostico)",
    entrada: "Descripcion, CostoEstimado",
    respuesta: "DiagnosticoID",
    roles: "TECNICO",
    estado: "ausente",
    procedimiento: "spRegistrarDiagnostico",
    nota: "Puede iniciar desde RECIBIDO y termina en ESPERANDO_AUTORIZACION. El tecnico proviene de la sesion.",
  },
  {
    id: "reparacion.iniciar",
    modulo: "Servicio tecnico",
    operacion: "Iniciar reparacion",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/reparaciones)",
    entrada: "DiagnosticoID, DescripcionTrabajo, CostoManoObra, Autorizacion",
    respuesta: "ReparacionID",
    roles: "TECNICO",
    estado: "ausente",
    procedimiento: "spIniciarReparacion",
    nota: "Exige diagnostico previo y constancia de autorizacion del cliente (se documenta en la observacion del cambio de estado).",
  },
  {
    id: "reparacion.actividad",
    modulo: "Servicio tecnico",
    operacion: "Registrar actividad",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/reparaciones/{id}/actividades)",
    entrada: "ActividadID, Observacion",
    respuesta: "ok",
    roles: "TECNICO",
    estado: "ausente",
    procedimiento: "spRegistrarActividad",
  },
  {
    id: "reparacion.consumir",
    modulo: "Servicio tecnico",
    operacion: "Consumir repuesto",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/reparaciones/{id}/repuestos)",
    entrada: "BodegaID, RepuestoID, Cantidad",
    respuesta: "ok",
    roles: "TECNICO",
    estado: "ausente",
    procedimiento: "spConsumirRepuesto",
    nota: "Validacion + consumo + movimiento de salida en una sola transaccion. El frontend no crea movimiento ni edita existencias.",
  },
  {
    id: "reparacion.cerrar",
    modulo: "Servicio tecnico",
    operacion: "Finalizar reparacion",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/reparaciones/{id}/cerrar)",
    entrada: "-",
    respuesta: "ok",
    roles: "TECNICO",
    estado: "ausente",
    procedimiento: "spCerrarReparacion",
    nota: "Termina la reparacion y deja la orden en LISTO.",
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
    operacion: "Usuarios, empleados y roles",
    metodo: "Sin endpoint",
    ruta: "(requiere /api/admin/usuarios)",
    entrada: "NombreUsuario, Activo, roles[]",
    respuesta: "Usuarios[]",
    roles: "ADMIN",
    estado: "ausente",
    nota: "PasswordHash y AlgoritmoHash nunca se consultan ni se muestran como datos.",
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
