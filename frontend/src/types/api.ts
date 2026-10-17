/**
 * DTO reales expuestos por el backend (Spring Boot + JdbcTemplate).
 *
 * IMPORTANTE: ClienteController usa `jdbc.queryForList(...)`, por lo que las
 * claves JSON conservan EL MISMO nombre de columna de SQL Server (PascalCase),
 * no camelCase. No renombrar estas propiedades: el contrato real es PascalCase.
 */

/** Cliente tal como lo devuelve GET /api/clientes y GET /api/clientes/{id}. */
export interface Cliente {
  ClienteID: number;
  TipoClienteID: number;
  NIT: string;
  Nombre: string;
  Email: string | null;
  Telefono: string | null;
  Direccion: string | null;
  Activo: boolean;
}

/** Cuerpo aceptado por POST /api/clientes y PUT /api/clientes/{id}. */
export interface ClienteDatos {
  tipoClienteId: number;
  nit: string;
  nombre: string;
  email: string | null;
  telefono: string | null;
  direccion: string | null;
  activo: boolean;
}

/** Formato de error devuelto por los @ExceptionHandler de ClienteController. */
export interface ApiErrorBody {
  estado: number;
  mensaje: string;
  errores?: Record<string, string>;
}
