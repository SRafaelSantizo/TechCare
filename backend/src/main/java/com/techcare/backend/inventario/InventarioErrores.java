package com.techcare.backend.inventario;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.server.ResponseStatusException;
import java.sql.SQLException;
import java.util.Map;

@RestControllerAdvice(assignableTypes=InventarioController.class)
public class InventarioErrores {
    private static final Logger LOG=LoggerFactory.getLogger(InventarioErrores.class);
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    ResponseEntity<Map<String,Object>> entrada(Exception e) { return error(400,"Revisá los identificadores, fechas, filtros y paginación."); }
    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<Map<String,Object>> estado(ResponseStatusException e) { return error(e.getStatusCode().value(),e.getReason()); }
    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<Map<String,Object>> sql(DataAccessException e) {
        for(Throwable c=e;c!=null;c=c.getCause())if(c instanceof SQLException s)
            for(SQLException x=s;x!=null;x=x.getNextException())switch(x.getErrorCode()) {
                case 52200: return error(400,"Revisá los identificadores, fechas, filtros y paginación.");
                case 52202: return error(404,"El repuesto no está asociado a esa bodega.");
                case 52004: return error(403,"Se requiere un usuario activo de bodega o administración.");
                case 1205,1222: return error(409,"La consulta coincidió con otra operación. Volvé a actualizar.");
                default: break;
            }
        LOG.error("No se pudo consultar inventario.",e);return error(503,"No se pudo consultar el inventario. Volvé a intentar.");
    }
    private static ResponseEntity<Map<String,Object>> error(int estado,String mensaje) { return ResponseEntity.status(estado).body(Map.of("estado",estado,"mensaje",mensaje)); }
}
