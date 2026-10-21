package com.techcare.backend.abastecimiento;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.server.ResponseStatusException;

import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice(assignableTypes=AbastecimientoController.class)
public class AbastecimientoErrores {
    private static final Logger LOG=LoggerFactory.getLogger(AbastecimientoErrores.class);
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String,Object>> validacion(MethodArgumentNotValidException ex) {
        Map<String,String> campos=new LinkedHashMap<>();ex.getBindingResult().getFieldErrors().forEach(e->campos.putIfAbsent(e.getField(),e.getDefaultMessage()));
        return ResponseEntity.badRequest().contentType(MediaType.APPLICATION_JSON).body(Map.of("estado",400,"mensaje","Revisá los datos del catálogo.","errores",campos));
    }
    @ExceptionHandler({HttpMessageNotReadableException.class,MethodArgumentTypeMismatchException.class})
    public ResponseEntity<Map<String,Object>> entrada(Exception ex) { return error(400,"La solicitud contiene datos inválidos."); }
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String,Object>> estado(ResponseStatusException ex) { return error(ex.getStatusCode().value(),ex.getReason()); }
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String,Object>> sql(DataAccessException ex) {
        for(Throwable c=ex;c!=null;c=c.getCause())if(c instanceof SQLException sql)
            for(SQLException s=sql;s!=null;s=s.getNextException())switch(s.getErrorCode()) {
                case 52000,52001: return error(400,s.getMessage());
                case 52002: return error(404,"El registro no existe o ya no está disponible.");
                case 52003: return error(409,s.getMessage());
                case 52004: return error(403,"Se requiere un usuario activo de bodega o administración.");
                case 2601,2627: return error(409,"Ese código, NIT o nombre de categoría ya está registrado. Revisá el listado.");
                case 547,1205,51120: return error(409,"Los datos o sus relaciones cambiaron. Actualizá el listado y volvé a revisar.");
                default: break;
            }
        LOG.error("No se pudo completar una operación de abastecimiento.",ex);
        return error(503,"No se pudo completar la operación. Revisá el backend e intentá nuevamente.");
    }
    private static ResponseEntity<Map<String,Object>> error(int estado,String mensaje) {
        return ResponseEntity.status(estado).contentType(MediaType.APPLICATION_JSON).body(Map.of("estado",estado,"mensaje",mensaje));
    }
}
