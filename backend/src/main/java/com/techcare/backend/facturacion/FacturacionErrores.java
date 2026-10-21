package com.techcare.backend.facturacion;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.server.ResponseStatusException;

import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice(assignableTypes=FacturacionController.class)
public class FacturacionErrores {
    private static final Logger LOG=LoggerFactory.getLogger(FacturacionErrores.class);
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String,Object>> validacion(MethodArgumentNotValidException ex) {
        Map<String,String> errores=new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(e -> errores.putIfAbsent(e.getField(),e.getDefaultMessage()));
        return ResponseEntity.badRequest().contentType(MediaType.APPLICATION_JSON).body(Map.of("estado",400,"mensaje","Revisá los datos de facturación o entrega.","errores",errores));
    }
    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
    public ResponseEntity<Map<String,Object>> entrada(Exception ex) { return error(400,"La solicitud contiene datos inválidos."); }
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String,Object>> estado(ResponseStatusException ex) { return error(ex.getStatusCode().value(),ex.getReason()); }
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String,Object>> sql(DataAccessException ex) {
        for(Throwable causa=ex;causa!=null;causa=causa.getCause()) if(causa instanceof SQLException sql)
            for(SQLException actual=sql;actual!=null;actual=actual.getNextException()) switch(actual.getErrorCode()) {
                case 51800: return error(400,actual.getMessage());
                case 51802: return error(404,"La orden no existe o no está disponible para tu usuario.");
                case 51803: return error(409,actual.getMessage());
                case 51804,51604,51031,51035,51039: return error(403,"Tu usuario activo no tiene permiso para esta operación.");
                case 51032,51033,51034,51036,51037,51038,51040,51041,51127,51128,51129,51130,51131,51140,2601,2627,547,1205:
                    return error(409,"Los datos, pagos o estado de la orden cambiaron. Actualizá el expediente antes de volver a confirmar.");
                default: break;
            }
        LOG.error("No se pudo completar la operación de caja o entrega.",ex);
        return error(503,"No se pudo completar la operación. Revisá el backend e intentá nuevamente.");
    }
    private static ResponseEntity<Map<String,Object>> error(int estado,String mensaje) {
        return ResponseEntity.status(estado).contentType(MediaType.APPLICATION_JSON).body(Map.of("estado",estado,"mensaje",mensaje));
    }
}
