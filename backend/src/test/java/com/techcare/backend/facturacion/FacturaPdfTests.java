package com.techcare.backend.facturacion;

import org.apache.pdfbox.Loader;
import org.apache.pdfbox.text.PDFTextStripper;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class FacturaPdfTests {
    private static final OffsetDateTime FECHA=OffsetDateTime.parse("2026-10-21T18:30:00Z");
    private static BigDecimal n(String v) { return new BigDecimal(v); }
    private FacturacionServicio.Factura factura(int cantidad,boolean anulada) {
        BigDecimal repuestos=n("51.00").multiply(BigDecimal.valueOf(cantidad-1));
        BigDecimal subtotal=n("100.00").add(repuestos), impuesto=subtotal.multiply(n("0.12")).setScale(2);
        BigDecimal total=subtotal.add(impuesto);
        return new FacturacionServicio.Factura(1,"TCF-45",81,"TC-81",FECHA,anulada?"ANULADA":"EMITIDA",
                "1234567-8","María José Núñez","Zona 1, Ciudad de Guatemala",n("0.12"),subtotal,n("100.00"),repuestos,
                impuesto,total,anulada?BigDecimal.ZERO:total,anulada?total:BigDecimal.ZERO,anulada?"ANULADA":"PAGADA","SERIE-Ñ-81",
                "Computadora portátil", "Marca", "Modelo", cantidad>3?"Se reparó la alimentación y se verificó con carga. ".repeat(35):"Se reemplazó la fuente y se verificó el encendido.",
                "Ana López / Caja","Óscar Muñoz / Técnico","Lucía Pérez / Recepción");
    }
    private byte[] generar(int cantidad,boolean anulada) {
        var detalles=new ArrayList<FacturacionServicio.Detalle>();
        detalles.add(new FacturacionServicio.Detalle(1,"MO","Mano de obra del servicio",1,n("100.00"),n("100.00")));
        for(int i=2;i<=cantidad;i++) detalles.add(new FacturacionServicio.Detalle(i,"REP",i==cantidad?"ÚLTIMO REPUESTO — Cable de alimentación ñ":"Fuente de alimentación — revisión y garantía "+i,
                2,n("25.50"),n("51.00")));
        var pagos=new ArrayList<FacturacionServicio.Pago>();
        int numeroPagos=anulada?0:cantidad>3?24:1;
        for(int i=0;i<numeroPagos;i++) pagos.add(new FacturacionServicio.Pago((long)i+1,FECHA,1,"Efectivo",
                i==numeroPagos-1?factura(cantidad,anulada).total().subtract(n("100").multiply(BigDecimal.valueOf(i))):n("100"),"Referencia válida ñ-"+i,"Ana López"));
        var entrega=new FacturacionServicio.Entrega(81,FECHA,"María José Núñez","1234-56789-0101","Equipo verificado con el cliente. Recibió accesorios completos.","Lucía Pérez / Recepción");
        return new FacturaPdf().generar(new FacturacionServicio.Documento(factura(cantidad,anulada),detalles,pagos,anulada?null:entrega));
    }
    @Test void facturaIncluyeDetalleImportesPersonasYPagosConTextoSeleccionable() throws Exception {
        byte[] pdf=generar(2,false);
        Files.createDirectories(Path.of("target/pdf-qa")); Files.write(Path.of("target/pdf-qa/factura-detallada.pdf"),pdf);
        try(var doc=Loader.loadPDF(pdf)) {
            String texto=new PDFTextStripper().getText(doc);
            for(String esperado:List.of("TCF-45","TC-81","María José Núñez","Lucía Pérez","Óscar Muñoz","Ana López",
                    "Mano de obra del servicio","ÚLTIMO REPUESTO — Cable","25.50","51.00","18.12","169.12","0.00","1234-56789-0101","Página 1"))
                assertTrue(texto.contains(esperado),esperado);
            assertFalse(texto.contains("SIN VALIDEZ"));
            assertTrue(doc.getPage(0).getResources().getFontNames().iterator().hasNext());
        }
    }
    @Test void muchasLineasYPagosNoSeTruncanYRepitenIdentificacionYPaginacion() throws Exception {
        byte[] pdf=generar(65,false);
        Files.createDirectories(Path.of("target/pdf-qa")); Files.write(Path.of("target/pdf-qa/factura-varias-paginas.pdf"),pdf);
        try(var doc=Loader.loadPDF(pdf)) {
            assertTrue(doc.getNumberOfPages()>=4);
            String texto=new PDFTextStripper().getText(doc);
            assertTrue(texto.contains("ÚLTIMO REPUESTO")); assertTrue(texto.contains("Referencia válida ñ-23"));
            assertTrue(texto.contains("Equipo verificado con el cliente"));
            for(int i=1;i<=doc.getNumberOfPages();i++) {
                var lector=new PDFTextStripper(); lector.setStartPage(i); lector.setEndPage(i);
                String pagina=lector.getText(doc);
                assertTrue(pagina.contains("TCF-45")); assertTrue(pagina.contains("EMITIDA"));
                assertTrue(pagina.contains("Página "+i+" de "+doc.getNumberOfPages()));
            }
        }
    }
    @Test void facturaAnuladaSeIdentificaEnTodasSusPaginas() throws Exception {
        try(var doc=Loader.loadPDF(generar(65,true))) {
            for(int i=1;i<=doc.getNumberOfPages();i++) {
                var lector=new PDFTextStripper(); lector.setStartPage(i); lector.setEndPage(i);
                assertTrue(lector.getText(doc).contains("ANULADA · SIN VALIDEZ"));
            }
        }
    }
}
