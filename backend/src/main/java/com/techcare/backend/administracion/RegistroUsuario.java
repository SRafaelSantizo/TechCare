package com.techcare.backend.administracion;

import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.HashSet;
import java.util.List;

public record RegistroUsuario(
        @NotBlank(message = "El usuario es obligatorio.")
        @Pattern(regexp = "[A-Za-z0-9._-]{3,50}", message = "Usá de 3 a 50 letras sin tildes, números, puntos o guiones.")
        String nombreUsuario,
        @NotBlank(message = "La contraseña es obligatoria.")
        @Size(min = 12, max = 256, message = "La contraseña debe tener entre 12 y 256 caracteres.")
        String contrasena,
        @NotEmpty(message = "Seleccioná al menos un rol.") @Size(max = 5, message = "Seleccioná hasta cinco roles.")
        List<@NotBlank(message = "El rol es obligatorio.")
                @Pattern(regexp = "[A-Z][A-Z0-9_]{0,19}", message = "El código de rol no es válido.") String> roles,
        @Min(value = 1, message = "Elegí un empleado válido.") Integer empleadoId,
        @Valid EmpleadoNuevo empleadoNuevo) {

    public RegistroUsuario {
        nombreUsuario = nombreUsuario == null ? null : nombreUsuario.strip();
        // La contraseña conserva todos sus caracteres, incluidos los espacios.
    }

    @AssertTrue(message = "Elegí un empleado existente o ingresá uno nuevo, usando una sola opción.")
    public boolean isEmpleadoSeleccionado() { return (empleadoId != null) != (empleadoNuevo != null); }

    @AssertTrue(message = "Los roles no pueden repetirse.")
    public boolean isRolesSinDuplicados() { return roles == null || new HashSet<>(roles).size() == roles.size(); }

    @Override public String toString() { return "RegistroUsuario[contraseña protegida]"; }

    public record EmpleadoNuevo(
            @NotBlank(message = "El código es obligatorio.")
            @Pattern(regexp = "[A-Za-z0-9._-]{1,20}", message = "El código admite hasta 20 letras sin tildes, números, puntos o guiones.") String codigo,
            @NotBlank(message = "Los nombres son obligatorios.") @Size(max = 80, message = "Los nombres admiten hasta 80 caracteres.") String nombres,
            @NotBlank(message = "Los apellidos son obligatorios.") @Size(max = 80, message = "Los apellidos admiten hasta 80 caracteres.") String apellidos) {
        public EmpleadoNuevo {
            codigo = codigo == null ? null : codigo.strip();
            nombres = nombres == null ? null : nombres.strip();
            apellidos = apellidos == null ? null : apellidos.strip();
        }
    }
}
