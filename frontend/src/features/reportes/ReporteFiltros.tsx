import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Field, SelectInput, TextInput } from "../../components/ui/inputs";
import { Button } from "../../components/ui/Button";
import { reportesApi } from "../../services/reportes";
import { mensajeDeError } from "../../services/errors";
export const etiquetasFiltro: Record<string, string> = { clienteId: "Cliente", tecnicoId: "Técnico", bodegaId: "Bodega", proveedorId: "Proveedor", ordenId: "Orden", categoriaId: "Categoría", repuestoId: "Repuesto", estado: "Estado", serie: "Número de serie exacto", desde: "Desde (día UTC)", hasta: "Hasta (día UTC, incluido)" };
export function FiltroReporte({ codigo, nombre, valor, onChange }: { codigo: string; nombre: string; valor: string; onChange: (v: string) => void }) {
  const [buscar, setBuscar] = useState(""), [busqueda, setBusqueda] = useState("");
  useEffect(() => { const timer = setTimeout(() => setBusqueda(buscar.trim()), 250); return () => clearTimeout(timer); }, [buscar]);
  const catalogo = !["serie", "desde", "hasta"].includes(nombre), label = etiquetasFiltro[nombre], id = `reporte-${nombre}`;
  const opciones = useQuery({ queryKey: ["reportes", "opciones", codigo, nombre, busqueda], queryFn: ({ signal }) => reportesApi.opciones(codigo, nombre, busqueda, signal), enabled: catalogo });
  if (!catalogo) return <Field label={label} htmlFor={id}><TextInput id={id} type={nombre === "serie" ? "text" : "date"} maxLength={nombre === "serie" ? 80 : undefined} min={nombre !== "serie" ? "0001-01-01" : undefined} max={nombre !== "serie" ? "9999-12-31" : undefined} value={valor} onChange={e => onChange(e.target.value)} /></Field>;
  return <Field label={label} htmlFor={id} hint="Hasta 100 coincidencias; escribí para buscar otras opciones.">
    <TextInput aria-label={`Buscar ${label.toLowerCase()}`} placeholder={`Buscar ${label.toLowerCase()}…`} maxLength={150} value={buscar} onChange={e => setBuscar(e.target.value)} />
    <SelectInput id={id} value={valor} disabled={opciones.isLoading || opciones.isError} onChange={e => onChange(e.target.value)}><option value="">Todos</option>
      {valor && !opciones.data?.some(o => o.valor === valor) ? <option value={valor}>Seleccionado: {valor}</option> : null}
      {opciones.data?.map(o => <option key={o.valor} value={o.valor}>{o.etiqueta}</option>)}
    </SelectInput>
    {opciones.isError ? <div role="alert" className="tc-field__error">{mensajeDeError(opciones.error)} <Button tamano="sm" onClick={() => opciones.refetch()}>Reintentar {label.toLowerCase()}</Button></div> : null}
  </Field>;
}
