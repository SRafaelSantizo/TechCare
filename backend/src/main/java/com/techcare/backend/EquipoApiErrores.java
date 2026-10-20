package com.techcare.backend;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice(assignableTypes = {EquipoController.class, CatalogoEquipoController.class})
public class EquipoApiErrores {
    private static final Logger LOG = LoggerFactory.getLogger(EquipoApiErrores.class);

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> validacion(MethodArgumentNotValidException ex) {
        Map<String, String> errores = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(e -> errores.putIfAbsent(e.getField(), e.getDefaultMessage()));
        return ResponseEntity.badRequest().body(Map.of(
                "estado", 400, "mensaje", "Revisá los datos del equipo.", "errores", errores));
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
    public ResponseEntity<Map<String, Object>> entrada(Exception ex) {
        return error(HttpStatus.BAD_REQUEST, "La solicitud contiene un JSON, ID o filtro inválido.");
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, Object>> sql(DataAccessException ex) {
        for (Throwable causa = ex; causa != null; causa = causa.getCause()) {
            if (!(causa instanceof SQLException sql)) continue;
            for (SQLException actual = sql; actual != null; actual = actual.getNextException()) {
                switch (actual.getErrorCode()) {
                    case 51300:
                    case 51301:
                        return error(HttpStatus.BAD_REQUEST, actual.getMessage());
                    case 51302:
                        return error(HttpStatus.NOT_FOUND, "El equipo no existe.");
                    case 51303:
                    case 2601:
                    case 2627:
                        return error(HttpStatus.CONFLICT, "La serie ya está registrada en otro equipo.");
                    case 51304:
                    case 51109:
                        return error(HttpStatus.CONFLICT, "El equipo tiene órdenes: no se puede cambiar su propietario, serie ni modelo.");
                    case 547:
                        return error(HttpStatus.CONFLICT, "Los datos ya no cumplen las relaciones de la base. Actualizá y volvé a intentar.");
                    default:
                        break;
                }
            }
        }
        LOG.error("No se pudo completar una operación de Equipos o sus catálogos.", ex);
        return error(HttpStatus.INTERNAL_SERVER_ERROR, "No se pudo completar la operación. Revisá el backend.");
    }

    private ResponseEntity<Map<String, Object>> error(HttpStatus estado, String mensaje) {
        return ResponseEntity.status(estado).body(Map.of("estado", estado.value(), "mensaje", mensaje));
    }
}
