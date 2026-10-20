package com.techcare.backend.seguridad;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TechCarePasswordEncoderTests {
    private final TechCarePasswordEncoder encoder=new TechCarePasswordEncoder();
    static final String HASH_DEMO="$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=";

    @Test void verificaElHashYaExistenteSinCambiarlo() {
        assertTrue(encoder.matches("TechCare2026!",HASH_DEMO));
        assertFalse(encoder.matches("OtraContraseña",HASH_DEMO));
    }
    @Test void conservaUnicodeYEspaciosEnLaContrasena() {
        String password=" Árbol ñ 漢字 🔐 ";
        String encoded=encoder.encode(password);
        assertTrue(encoder.matches(password,encoded));
        assertFalse(encoder.matches(password.strip(),encoded));
    }
    @Test void dosHashesDeLaMismaContrasenaUsanSaltDistinto() {
        assertNotEquals(encoder.encode("Contraseña de prueba"),encoder.encode("Contraseña de prueba"));
    }
    @Test void rechazaFormatosDanadosYCostosExcesivos() {
        for (String hash:new String[]{"texto", "$pbkdf2-sha256$1$a$b", HASH_DEMO.replace("600000","2147483647"),
                HASH_DEMO.replace("HuxZ","!!!!"),HASH_DEMO+"$extra",HASH_DEMO.replace("pbkdf2-sha256","sha256")})
            assertFalse(encoder.matches("TechCare2026!",hash));
        assertFalse(encoder.matches(null,HASH_DEMO));
        assertFalse(encoder.matches("x",null));
        assertFalse(encoder.matches("x".repeat(257),HASH_DEMO));
    }
}
