package com.techcare.backend;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DataRetrievalFailureException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.server.ResponseStatusException;

import java.net.URI;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/clientes")
public class ClienteController {

    private static final Logger LOG = LoggerFactory.getLogger(ClienteController.class);

    private final JdbcTemplate jdbc;

    public ClienteController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<Map<String, Object>> listarClientes() {
        return jdbc.queryForList("EXEC dbo.spListarClientes");
    }

    @GetMapping("/{id}")
    public Map<String, Object> consultarCliente(@PathVariable("id") int id) {
        validarId(id);
        return obtenerCliente(jdbc.queryForList("EXEC dbo.spConsultarCliente ?", id));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> registrarCliente(
            @Valid @RequestBody ClienteDatos datos) {

        Map<String, Object> cliente = obtenerCliente(jdbc.queryForList(
                "EXEC dbo.spRegistrarCliente ?, ?, ?, ?, ?, ?, ?",
                datos.tipoClienteId(), datos.nit(), datos.nombre(), datos.email(),
                datos.telefono(), datos.direccion(), datos.activo()));

        Number id = (Number) cliente.get("ClienteID");
        return ResponseEntity.created(URI.create("/api/clientes/" + id.intValue()))
                .body(cliente);
    }

    @PutMapping("/{id}")
    public Map<String, Object> actualizarCliente(
            @PathVariable("id") int id,
            @Valid @RequestBody ClienteDatos datos) {

        validarId(id);
        return obtenerCliente(jdbc.queryForList(
                "EXEC dbo.spActualizarCliente ?, ?, ?, ?, ?, ?, ?, ?",
                id, datos.tipoClienteId(), datos.nit(), datos.nombre(), datos.email(),
                datos.telefono(), datos.direccion(), datos.activo()));
    }

    private Map<String, Object> obtenerCliente(List<Map<String, Object>> clientes) {
        if (clientes.size() != 1 || !(clientes.get(0).get("ClienteID") instanceof Number)) {
            throw new DataRetrievalFailureException(
                    "El procedimiento no devolvió un cliente válido.");
        }
        return clientes.get(0);
    }

    private void validarId(int id) {
        if (id <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El ID debe ser mayor que cero.");
        }
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> manejarEstado(ResponseStatusException ex) {
        return ResponseEntity.status(ex.getStatusCode()).body(Map.of(
                "estado", ex.getStatusCode().value(),
                "mensaje", ex.getReason() == null ? "Solicitud inválida." : ex.getReason()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> manejarValidacion(MethodArgumentNotValidException ex) {
        Map<String, String> errores = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error ->
                errores.putIfAbsent(error.getField(), error.getDefaultMessage()));

        return ResponseEntity.badRequest().body(Map.of(
                "estado", 400,
                "mensaje", "Revisá los datos del cliente.",
                "errores", errores));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, Object>> manejarJson(HttpMessageNotReadableException ex) {
        return error(HttpStatus.BAD_REQUEST, "El JSON es inválido o contiene tipos de datos incorrectos.");
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Map<String, Object>> manejarIdInvalido(MethodArgumentTypeMismatchException ex) {
        return error(HttpStatus.BAD_REQUEST, "El ID debe ser un número entero válido.");
    }

    @ExceptionHandler(DuplicateKeyException.class)
    public ResponseEntity<Map<String, Object>> manejarDuplicado(DuplicateKeyException ex) {
        return error(HttpStatus.CONFLICT, "El NIT ya está registrado en otro cliente.");
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> manejarIntegridad(DataIntegrityViolationException ex) {
        ResponseEntity<Map<String, Object>> respuesta = traducirErrorSql(ex);
        return respuesta != null ? respuesta : error(HttpStatus.CONFLICT,
                "Los datos incumplen una regla de integridad de la base de datos.");
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, Object>> manejarBaseDatos(DataAccessException ex) {
        ResponseEntity<Map<String, Object>> respuesta = traducirErrorSql(ex);
        if (respuesta != null) {
            return respuesta;
        }
        LOG.error("No se pudo completar una operación del módulo de Clientes.", ex);
        return error(HttpStatus.INTERNAL_SERVER_ERROR, "No se pudo completar la operación. Revisá el backend.");
    }

    private ResponseEntity<Map<String, Object>> traducirErrorSql(DataAccessException ex) {
        // THROW conserva el número de error de SQL Server. La API lo traduce a HTTP.
        Throwable causa = ex;
        while (causa != null) {
            if (causa instanceof SQLException sql) {
                for (SQLException actual = sql; actual != null; actual = actual.getNextException()) {
                    switch (actual.getErrorCode()) {
                        case 51200:
                        case 51201:
                            return error(HttpStatus.BAD_REQUEST, actual.getMessage());
                        case 51202:
                            return error(HttpStatus.NOT_FOUND, "El cliente no existe.");
                        case 51203:
                        case 2601:
                        case 2627:
                            return error(HttpStatus.CONFLICT, "El NIT ya está registrado en otro cliente.");
                        default:
                            break;
                    }
                }
            }
            causa = causa.getCause();
        }
        return null;
    }

    private ResponseEntity<Map<String, Object>> error(HttpStatus estado, String mensaje) {
        return ResponseEntity.status(estado).body(Map.of(
                "estado", estado.value(), "mensaje", mensaje));
    }

    public record ClienteDatos(
            @NotNull(message = "El tipo de cliente es obligatorio.")
            @Min(value = 1, message = "El tipo de cliente debe ser mayor que cero.")
            @Max(value = 255, message = "El tipo de cliente debe ser menor o igual a 255.")
            Integer tipoClienteId,

            @NotBlank(message = "El NIT es obligatorio.")
            @Size(max = 20, message = "El NIT admite hasta 20 caracteres.")
            String nit,

            @NotBlank(message = "El nombre es obligatorio.")
            @Size(max = 150, message = "El nombre admite hasta 150 caracteres.")
            String nombre,

            @Email(message = "El correo no tiene un formato válido.")
            @Size(max = 254, message = "El correo admite hasta 254 caracteres.")
            String email,

            @Size(max = 25, message = "El teléfono admite hasta 25 caracteres.")
            String telefono,

            @Size(max = 250, message = "La dirección admite hasta 250 caracteres.")
            String direccion,

            @NotNull(message = "Activo es obligatorio: usá true o false.")
            Boolean activo) {

        public ClienteDatos {
            nit = limpiar(nit);
            nombre = limpiar(nombre);
            email = limpiar(email);
            telefono = limpiar(telefono);
            direccion = limpiar(direccion);
        }

        private static String limpiar(String valor) {
            return valor == null || valor.isBlank() ? null : valor.strip();
        }
    }
}
