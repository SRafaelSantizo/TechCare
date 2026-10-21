package com.techcare.backend.facturacion;

import org.apache.pdfbox.pdmodel.*;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDType0Font;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.math.BigDecimal;
import java.text.NumberFormat;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.HashMap;
import java.util.Map;

@Component
public class FacturaPdf {
    public byte[] generar(FacturacionServicio.Documento datos) {
        try (var documento = new PDDocument(); var salida = new ByteArrayOutputStream()) {
            var info = documento.getDocumentInformation();
            info.setTitle("Factura " + datos.factura().numeroFactura());
            info.setAuthor("TechCare"); info.setSubject("Detalle del servicio, responsables, pagos y entrega");
            new Diseno(documento, datos).dibujar();
            documento.save(salida);
            return salida.toByteArray();
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "No se pudo generar el PDF. Volvé a intentar la descarga.", e);
        }
    }

    private static final class Diseno {
        private static final Color TINTA = new Color(30,49,58), VERDE = new Color(11,103,108), GRIS = new Color(236,243,244);
        private static final float M = 42, DERECHA = PDRectangle.A4.getWidth()-M, ANCHO = DERECHA-M;
        private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm").withZone(ZoneId.of("America/Guatemala"));
        private final PDDocument doc;
        private final FacturacionServicio.Documento datos;
        private final PDType0Font normal, negrita;
        private final NumberFormat numeros = NumberFormat.getNumberInstance(Locale.US);
        private final Map<Integer,String> glifos = new HashMap<>();
        private PDPageContentStream lienzo;
        private float y;

        Diseno(PDDocument doc, FacturacionServicio.Documento datos) throws IOException {
            this.doc=doc; this.datos=datos;
            try(var a=fuente("DejaVuSans.ttf"); var b=fuente("DejaVuSans-Bold.ttf")) {
                normal=PDType0Font.load(doc,a,true); negrita=PDType0Font.load(doc,b,true);
            }
            numeros.setMinimumFractionDigits(2); numeros.setMaximumFractionDigits(2);
        }
        private InputStream fuente(String archivo) throws IOException {
            var stream=FacturaPdf.class.getResourceAsStream("/pdf/fonts/"+archivo);
            if(stream==null) throw new IOException("Falta la fuente PDF empaquetada.");
            return stream;
        }
        void dibujar() throws IOException {
            var f=datos.factura();
            nuevaPagina();
            seccion("Cliente, equipo y responsables");
            var cliente=new ArrayList<>(List.of("Nombre: "+valor(f.nombreFacturacion()),"NIT: "+valor(f.nitFacturacion()),
                    "Dirección: "+valor(f.direccionFacturacion()),"Equipo: "+valor(f.marca())+" "+valor(f.modelo()),"Serie: "+valor(f.numeroSerie())));
            if(f.equipoDescripcion()!=null) cliente.add("Descripción: "+f.equipoDescripcion());
            columnas(cliente,List.of("Atendió / recibió la orden: "+valor(f.recepcionista()),
                    "Técnico responsable: "+valor(f.tecnico()),"Emitió la factura: "+valor(f.emitidaPor())));
            seccion("Trabajo realizado");
            parrafo(valor(f.descripcionTrabajo()));
            seccion("Detalle facturado");
            cabeceraTabla();
            for(var d:datos.detalles()) fila(d);
            espacio(14);
            importe("Subtotal",f.subtotal(),false);
            importe("Impuesto ("+f.tasaImpuesto().movePointRight(2).stripTrailingZeros().toPlainString()+" %)",f.impuesto(),false);
            importe("TOTAL",f.total(),true);
            seccion("Pagos y saldo al descargar");
            parrafo("Estado de pago: "+valor(f.estadoPago()));
            if(datos.pagos().isEmpty()) parrafo("Sin abonos registrados.");
            for(var p:datos.pagos()) {
                var lineas=envolver(fecha(p.fecha())+" · "+valor(p.metodoPago())+" · "+dinero(p.monto()),ANCHO,normal,9.5f);
                var ref=envolver("Referencia: "+valor(p.referencia())+" · Registró: "+valor(p.registradoPor()),ANCHO,normal,9);
                asegurar((lineas.size()+ref.size())*14+9);
                for(String linea:lineas) { texto(linea,M,y,normal,9.5f,TINTA); y-=14; }
                for(String linea:ref) { texto(linea,M,y,normal,9,TINTA); y-=14; }
                y-=9;
            }
            importe("Pagado",f.pagado(),false);
            importe("SALDO",f.saldo(),true);
            seccion("Entrega del equipo");
            if(datos.entrega()==null) parrafo("Entrega pendiente de registrar.");
            else {
                var e=datos.entrega();
                parrafo("Fecha de entrega: "+fecha(e.fecha()));
                parrafo("Recibió el equipo: "+valor(e.nombreRecibe()));
                parrafo("Documento: "+valor(e.documentoRecibe()));
                parrafo("Entregó: "+valor(e.entregadaPor()));
                if(e.observaciones()!=null) parrafo("Observaciones: "+e.observaciones());
            }
            lienzo.close();
            int total=doc.getNumberOfPages();
            for(int i=0;i<total;i++) {
                try(var pie=new PDPageContentStream(doc,doc.getPage(i),PDPageContentStream.AppendMode.APPEND,true,true)) {
                    lienzo=pie;
                    texto("TechCare · GTQ · Hora de Guatemala",M,29,normal,8,TINTA);
                    String pagina="Página "+(i+1)+" de "+total;
                    texto(pagina,DERECHA-ancho(pagina,normal,8),29,normal,8,TINTA);
                }
            }
        }
        private void nuevaPagina() throws IOException {
            if(lienzo!=null) lienzo.close();
            var pagina=new PDPage(PDRectangle.A4); doc.addPage(pagina);
            lienzo=new PDPageContentStream(doc,pagina);
            float alto=pagina.getMediaBox().getHeight();
            lienzo.setNonStrokingColor(VERDE); lienzo.addRect(0,alto-105,pagina.getMediaBox().getWidth(),105); lienzo.fill();
            texto("TechCare",M,alto-37,negrita,22,Color.WHITE);
            texto("FACTURA DE SERVICIO",M,alto-58,normal,10,Color.WHITE);
            var f=datos.factura();
            texto(valor(f.numeroFactura()),M,alto-83,negrita,12,Color.WHITE);
            String orden="Orden "+valor(f.numeroOrden());
            texto(orden,DERECHA-ancho(orden,normal,10),alto-35,normal,10,Color.WHITE);
            String fecha=fecha(f.fecha());
            texto(fecha,DERECHA-ancho(fecha,normal,9),alto-54,normal,9,Color.WHITE);
            String estado="ANULADA".equals(f.estado())?"ANULADA · SIN VALIDEZ":"EMITIDA";
            texto(estado,DERECHA-ancho(estado,negrita,9),alto-80,negrita,9,Color.WHITE);
            y=alto-130;
        }
        private void asegurar(float altura) throws IOException { if(y-altura<57) nuevaPagina(); }
        private void espacio(float alto) throws IOException { asegurar(alto); y-=alto; }
        private void seccion(String titulo) throws IOException {
            asegurar(55); y-=9;
            texto(titulo,M,y,negrita,11,VERDE); y-=21;
        }
        private void parrafo(String texto) throws IOException {
            for(String linea:envolver(texto,ANCHO,normal,9.5f)) {
                asegurar(15); texto(linea,M,y,normal,9.5f,TINTA); y-=14;
            }
            y-=4;
        }
        private void columnas(List<String> izquierda,List<String> derecha) throws IOException {
            float ancho=(ANCHO-24)/2;
            var a=new ArrayList<String>(); var b=new ArrayList<String>();
            for(String p:izquierda) { a.addAll(envolver(p,ancho,normal,9)); a.add(""); }
            for(String p:derecha) { b.addAll(envolver(p,ancho,normal,9)); b.add(""); }
            for(int i=0;i<Math.max(a.size(),b.size());i++) {
                asegurar(13);
                if(i<a.size()&&!a.get(i).isEmpty()) texto(a.get(i),M,y,normal,9,TINTA);
                if(i<b.size()&&!b.get(i).isEmpty()) texto(b.get(i),M+ancho+24,y,normal,9,TINTA);
                // Los separadores entre campos usan menos espacio que una línea de texto.
                boolean vacia=(i>=a.size()||a.get(i).isEmpty())&&(i>=b.size()||b.get(i).isEmpty());
                y-=vacia?4:13;
            }
        }
        private void cabeceraTabla() throws IOException {
            asegurar(45);
            lienzo.setNonStrokingColor(GRIS); lienzo.addRect(M,y-9,ANCHO,24); lienzo.fill();
            texto("#",M+4,y,negrita,8,TINTA); texto("Concepto",M+30,y,negrita,8,TINTA);
            texto("Cant.",M+268,y,negrita,8,TINTA);
            derecha("P. unitario",M+397,y,negrita,8,97);
            derecha("Importe",DERECHA-5,y,negrita,8,97); y-=25;
        }
        private void fila(FacturacionServicio.Detalle d) throws IOException {
            var lineas=envolver(valor(d.concepto()),230,normal,9);
            float alto=Math.max(25,lineas.size()*13+12);
            if(y-alto<57) { nuevaPagina(); cabeceraTabla(); }
            texto(String.valueOf(d.linea()),M+4,y,normal,8,TINTA);
            float pos=y;
            for(String linea:lineas) { texto(linea,M+30,pos,normal,9,TINTA); pos-=13; }
            derecha(String.valueOf(d.cantidad()),M+294,y,normal,9,34);
            derecha(dinero(d.precioUnitario()),M+397,y,normal,9,97);
            derecha(dinero(d.importe()),DERECHA-5,y,normal,9,97);
            y-=alto;
            lienzo.setStrokingColor(GRIS); lienzo.moveTo(M,y+6); lienzo.lineTo(DERECHA,y+6); lienzo.stroke();
        }
        private void importe(String etiqueta,BigDecimal monto,boolean destacado) throws IOException {
            asegurar(28);
            if(destacado) { lienzo.setNonStrokingColor(GRIS); lienzo.addRect(M,y-8,ANCHO,25); lienzo.fill(); }
            texto(etiqueta,M+10,y,destacado?negrita:normal,destacado?11:10,TINTA);
            derecha(dinero(monto),DERECHA-10,y,destacado?negrita:normal,destacado?11:10,220); y-=27;
        }
        private void derecha(String s,float x,float y,PDType0Font fuente,float tamano,float max) throws IOException {
            s=limpiar(s); float ancho=ancho(s,fuente,tamano);
            if(ancho>max) tamano*=max/ancho;
            texto(s,x-ancho(s,fuente,tamano),y,fuente,tamano,TINTA);
        }
        private void texto(String s,float x,float y,PDType0Font fuente,float tamano,Color color) throws IOException {
            lienzo.beginText(); lienzo.setFont(fuente,tamano); lienzo.setNonStrokingColor(color);
            lienzo.newLineAtOffset(x,y); lienzo.showText(limpiar(s)); lienzo.endText();
        }
        private String limpiar(String s) throws IOException {
            StringBuilder b=new StringBuilder();
            for(int cp:(s==null?"":s).codePoints().toArray()) {
                String glifo=glifos.get(cp);
                if(glifo==null) {
                    glifo=Character.isISOControl(cp)?" ":new String(Character.toChars(cp));
                    try { normal.encode(glifo); negrita.encode(glifo); }
                    catch(IllegalArgumentException e) { glifo="□"; }
                    glifos.put(cp,glifo);
                }
                b.append(glifo);
            }
            return b.toString();
        }
        private List<String> envolver(String entrada,float max,PDType0Font fuente,float tamano) throws IOException {
            var resultado=new ArrayList<String>();
            for(String parrafo:valor(entrada).replace("\r\n","\n").split("\n",-1)) {
                String actual="";
                for(String palabra:limpiar(parrafo).split("\\s+")) {
                    String candidato=actual.isEmpty()?palabra:actual+" "+palabra;
                    if(ancho(candidato,fuente,tamano)<=max) { actual=candidato; continue; }
                    if(!actual.isEmpty()) { resultado.add(actual); actual=""; }
                    for(int cp:palabra.codePoints().toArray()) {
                        String c=new String(Character.toChars(cp));
                        if(!actual.isEmpty()&&ancho(actual+c,fuente,tamano)>max) { resultado.add(actual); actual=""; }
                        actual+=c;
                    }
                }
                resultado.add(actual);
            }
            return resultado;
        }
        private float ancho(String s,PDType0Font fuente,float tamano) throws IOException { return fuente.getStringWidth(limpiar(s))*tamano/1000; }
        private String dinero(BigDecimal v) { return "Q "+numeros.format(v==null?BigDecimal.ZERO:v); }
        private static String valor(String v) { return v==null||v.isBlank()?"—":v; }
        private static String fecha(OffsetDateTime v) { return v==null?"—":FECHA.format(v); }
    }
}
