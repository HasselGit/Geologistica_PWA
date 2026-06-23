/// Constantes de estado centralizadas para toda la aplicación GeoLogística.
/// Todos los estados deben usarse desde aquí para evitar strings duplicados.
class AppStates {
  AppStates._();

  // ── Estados comunes ────────────────────────────────────────────────────────
  static const String pendiente  = 'Pendiente';
  static const String asignada   = 'Asignada';
  static const String enCurso    = 'En Curso';
  static const String terminado  = 'Terminado';

  // ── Estados de Solicitudes ─────────────────────────────────────────────────
  // Pendiente  → recién creada, disponible para planificar
  // Asignada   → incluida en un viaje que aún no ha iniciado (Pendiente/Planificado)
  // En Curso   → el viaje asociado ha iniciado
  // Terminado  → parada completada con remito generado

  // ── Estados de Viajes ─────────────────────────────────────────────────────
  // Pendiente  → viaje planificado, esperando carga o salida
  // En Curso   → chofer inició el viaje
  // Terminado  → todas las paradas completadas

  // ── Estados de Paradas ────────────────────────────────────────────────────
  // Pendiente  → parada no visitada
  // En Curso   → chofer en camino o en la parada
  // Terminado  → remito generado

  // ── Estados de Cargas ─────────────────────────────────────────────────────
  // Pendiente  → asignada al viaje, pendiente de carga física
  // En Curso   → Encargado de Depósito iniciando la carga
  // Terminado  → carga completada, depósito circulante actualizado

  /// Normaliza strings de estados anteriores al nuevo estándar.
  static String normalize(String? raw) {
    if (raw == null) return pendiente;
    final clean = raw.trim().toLowerCase();
    
    if (clean == 'planificado' || clean == 'planificada' || clean == 'cargado') {
      return pendiente;
    }
    if (clean == 'en proceso' || clean == 'en curso' || clean == 'enproceso' || clean == 'encurso') {
      return enCurso;
    }
    if (clean == 'asignada' || clean == 'asignado') {
      return asignada;
    }
    if (clean == 'finalizado' || clean == 'completado' || clean == 'completada' || clean == 'terminado' || clean == 'terminada') {
      return terminado;
    }
    
    // Si no coincide con ninguno, devolver el original capitalizado si es posible
    if (raw.isNotEmpty) {
      return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
    }
    return raw;
  }

  /// Color de fondo del badge según estado.
  static int stateBgColor(String estado) {
    switch (estado) {
      case asignada:   return 0xFFE3F2FD; // Azul muy claro
      case enCurso:    return 0xFFFDEFCC; // Ambar
      case terminado:  return 0xFFD4F0E1; // Esmeralda
      default:         return 0xFFF5F5F5; // Gris (Pendiente)
    }
  }

  /// Color de texto del badge según estado.
  static int stateTextColor(String estado) {
    switch (estado) {
      case asignada:   return 0xFF1976D2; // Azul fuerte
      case enCurso:    return 0xFF7D5700; // Marron/Ambar oscuro
      case terminado:  return 0xFF1A6B43; // Esmeralda oscuro
      default:         return 0xFF757575; // Gris oscuro
    }
  }

  /// Color del borde izquierdo de tarjeta según estado.
  static int stateBorderColor(String estado) {
    switch (estado) {
      case asignada:   return 0xFF2196F3;
      case enCurso:    return 0xFFFDBE49;
      case terminado:  return 0xFF249689;
      default:         return 0xFFBDBDBD;
    }
  }
}
