package com.techcare.backend;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.authentication.InternalAuthenticationServiceException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice(assignableTypes=AuthController.class)
public class AuthErrores {
    private static final Logger LOG=LoggerFactory.getLogger(AuthErrores.class);

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<Map<String,Object>> acceso(AuthenticationException ex) {
        if (ex instanceof InternalAuthenticationServiceException) return servicio(ex);
        return ResponseEntity.status(401).body(Map.of("estado",401,"mensaje","Usuario o contraseña incorrectos."));
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String,Object>> servicio(Exception ex) {
        LOG.error("No se pudo consultar el servicio de acceso.",ex);
        return ResponseEntity.status(503).body(Map.of("estado",503,"mensaje","No se pudo validar el acceso. Revisá el backend e intentá nuevamente."));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String,Object>> datos(MethodArgumentNotValidException ex) {
        Map<String,String> errores=new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(e -> errores.putIfAbsent(e.getField(),e.getDefaultMessage()));
        return ResponseEntity.badRequest().body(Map.of("estado",400,"mensaje","Revisá los datos de acceso.","errores",errores));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String,Object>> json(HttpMessageNotReadableException ex) {
        return ResponseEntity.badRequest().body(Map.of("estado",400,"mensaje","La solicitud de acceso no tiene un formato válido."));
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String,Object>> estado(ResponseStatusException ex) {
        return ResponseEntity.status(ex.getStatusCode()).body(Map.of("estado",ex.getStatusCode().value(),"mensaje",ex.getReason()));
    }
}
