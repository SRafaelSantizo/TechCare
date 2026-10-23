package com.techcare.backend.reportes;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.server.ResponseStatusException;
import java.sql.SQLException;
import java.util.Map;
@RestControllerAdvice(assignableTypes=ReportesController.class)
public class ReportesErrores {
 private static final Logger LOG=LoggerFactory.getLogger(ReportesErrores.class);
 @ExceptionHandler({MethodArgumentTypeMismatchException.class,MissingServletRequestParameterException.class})
 ResponseEntity<Map<String,Object>> entrada(Exception e) { return error(400,"Revisá el reporte, sus filtros y la paginación."); }
 @ExceptionHandler(ResponseStatusException.class)
 ResponseEntity<Map<String,Object>> estado(ResponseStatusException e) { return error(e.getStatusCode().value(),e.getReason()); }
 @ExceptionHandler(DataAccessException.class)
 ResponseEntity<Map<String,Object>> sql(DataAccessException e) {
  for(Throwable c=e;c!=null;c=c.getCause())if(c instanceof SQLException s)
   for(SQLException x=s;x!=null;x=x.getNextException())switch(x.getErrorCode()) {
    case 52300: return error(400,"Los filtros no son válidos para este reporte.");
    case 52302: return error(404,"El reporte no existe.");
    case 52304: return error(403,"Tu usuario no tiene permiso para este reporte o alcance.");
    case 1205,1222: return error(409,"La consulta coincidió con otra operación. Volvé a actualizar el reporte.");
    default: break;
   }
  LOG.error("No se pudo consultar el reporte.",e);return error(503,"No se pudo consultar el reporte. Volvé a intentar.");
 }
 private static ResponseEntity<Map<String,Object>> error(int estado,String mensaje) { return ResponseEntity.status(estado).body(Map.of("estado",estado,"mensaje",mensaje)); }
}
