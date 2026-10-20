package com.techcare.backend.administracion;

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
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice(assignableTypes = UsuarioAdminController.class)
public class UsuarioAdminErrores {
    private static final Logger LOG = LoggerFactory.getLogger(UsuarioAdminErrores.class);

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> validacion(MethodArgumentNotValidException ex) {
        Map<String, String> errores = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(e -> errores.putIfAbsent(e.getField(), e.getDefaultMessage()));
        return ResponseEntity.badRequest().body(Map.of("estado", 400, "mensaje", "Revisá los datos del usuario.", "errores", errores));
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
    public ResponseEntity<Map<String, Object>> entrada(Exception ex) { return error(400, "La solicitud contiene datos inválidos."); }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> estado(ResponseStatusException ex) {
        return error(ex.getStatusCode().value(), ex.getReason());
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, Object>> sql(DataAccessException ex) {
        for (Throwable causa = ex; causa != null; causa = causa.getCause()) {
            if (!(causa instanceof SQLException sql)) continue;
            for (SQLException actual = sql; actual != null; actual = actual.getNextException()) {
                switch (actual.getErrorCode()) {
                    case 51500, 51501: return error(400, actual.getMessage());
                    case 51502: return error(404, "El usuario no existe.");
                    case 51503: return error(409, actual.getMessage());
                    case 2601, 2627: return error(409, "El usuario o el empleado ya están registrados.");
                    case 51504: return error(403, "La operación requiere un administrador activo.");
                    case 547: return error(409, "El empleado o los roles cambiaron. Actualizá y volvé a intentar.");
                    default: break;
                }
            }
        }
        LOG.error("No se pudo completar una operación de administración de usuarios.", ex);
        return error(503, "No se pudo completar la operación. Revisá el backend e intentá nuevamente.");
    }

    private ResponseEntity<Map<String, Object>> error(int estado, String mensaje) {
        return ResponseEntity.status(estado).body(Map.of("estado", estado, "mensaje", mensaje));
    }
}
