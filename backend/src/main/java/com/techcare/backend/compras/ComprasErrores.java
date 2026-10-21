package com.techcare.backend.compras;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.server.ResponseStatusException;
import java.sql.SQLException;
import java.util.Map;

@RestControllerAdvice(assignableTypes=ComprasController.class)
public class ComprasErrores {
    private static final Logger LOG=LoggerFactory.getLogger(ComprasErrores.class);
    @ExceptionHandler({MethodArgumentNotValidException.class,HttpMessageNotReadableException.class,MethodArgumentTypeMismatchException.class})
    ResponseEntity<Map<String,Object>> entrada(Exception e) { return error(400,"Revisá número de compra, proveedor, líneas, cantidades, costos y confirmación."); }
    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<Map<String,Object>> estado(ResponseStatusException e) { return error(e.getStatusCode().value(),e.getReason()); }
    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<Map<String,Object>> sql(DataAccessException e) {
        for(Throwable c=e;c!=null;c=c.getCause())if(c instanceof SQLException s)
            for(SQLException x=s;x!=null;x=x.getNextException())switch(x.getErrorCode()) {
                case 52100,52101: return error(400,x.getMessage());
                case 52102: return error(404,"La compra o el repuesto no existe.");
                case 52103: return error(409,x.getMessage());
                case 52004: return error(403,"Se requiere un usuario activo de bodega o administración.");
                case 2601,2627: return error(409,"Ese número de compra ya está registrado. Revisá el listado antes de repetirla.");
                case 51027,51030,51120,51125,547,1205: return error(409,"La compra o su destino cambió. Actualizá el expediente y volvé a revisar.");
                default: break;
            }
        LOG.error("No se pudo completar la operación de compras.",e);return error(503,"No se pudo confirmar la operación. Actualizá el listado o reintentá la misma solicitud.");
    }
    private static ResponseEntity<Map<String,Object>> error(int estado,String mensaje) { return ResponseEntity.status(estado).body(Map.of("estado",estado,"mensaje",mensaje)); }
}
