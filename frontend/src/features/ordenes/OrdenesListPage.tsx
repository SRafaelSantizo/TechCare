import { PendingModule } from "../../components/ui/PendingModule";

export function OrdenesListPage() {
  return (
    <PendingModule
      modulo="Ordenes"
      titulo="Ordenes de servicio"
      descripcion="Todas las ordenes de servicio con busqueda y filtros por estado, prioridad, tecnico y fechas."
    />
  );
}
