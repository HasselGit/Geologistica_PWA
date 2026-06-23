import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseManager {
  static final client = Supabase.instance.client;
}

abstract class SupabaseTable<R> {
  String get tableName;
  R mapRow(Map<String, dynamic> data);

  Future<List<R>> queryRows({
    required Function(PostgrestFilterBuilder) queryFn,
  }) async {
    final query = SupabaseManager.client.from(tableName).select();
    final response = await queryFn(query);
    return (response as List).map((e) => mapRow(e)).toList();
  }

  Future<List<R>> querySingleRow({
    required Function(PostgrestFilterBuilder) queryFn,
  }) async {
    return queryRows(queryFn: queryFn);
  }
}

extension SupabaseFilterExtensions on PostgrestFilterBuilder {
  PostgrestFilterBuilder eqOrNull(String column, dynamic value) {
    if (value == null) return this;
    return eq(column, value);
  }
}

// VIAJES TABLE
class ViajesTable extends SupabaseTable<ViajesRow> {
  @override
  String get tableName => 'viajes';
  @override
  ViajesRow mapRow(Map<String, dynamic> data) => ViajesRow(data);
}

class ViajesRow {
  ViajesRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  String? get viajeCodigo => data['viaje_codigo'];
  String? get choferId => data['chofer_id'];
  String? get vehiculoCodigo => data['vehiculo_codigo'];
  String? get estado => data['estado'];
  String? get descripcion => data['descripcion'];
  DateTime? get fecha => DateTime.tryParse(data['fecha'] ?? '');
  DateTime? get fechaInicio => DateTime.tryParse(data['fecha_inicio'] ?? '');
  DateTime? get fechaFin => DateTime.tryParse(data['fecha_fin'] ?? '');
}

// PARADA ITEMS TABLE
class ParadaItemsTable extends SupabaseTable<ParadaItemsRow> {
  @override
  String get tableName => 'parada_items';
  @override
  ParadaItemsRow mapRow(Map<String, dynamic> data) => ParadaItemsRow(data);
}

class ParadaItemsRow {
  ParadaItemsRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  double? get cantidad => data['cantidad']?.toDouble();
  String? get productoId => data['producto_id'];
}

// V_PARADAS_CON_APICULTOR_FF (View)
class VParadasConApicultorFfTable extends SupabaseTable<VParadasConApicultorFfRow> {
  @override
  String get tableName => 'v_paradas_con_apicultor_ff';
  @override
  VParadasConApicultorFfRow mapRow(Map<String, dynamic> data) => VParadasConApicultorFfRow(data);
}

class VParadasConApicultorFfRow {
  VParadasConApicultorFfRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  String? get viajeId => data['viaje_id'];
  int? get ordenSecuencia => data['orden_secuencia'];
  String? get tipo => data['tipo'];
  String? get localidad => data['localidad'];
}

// VEHICULOS TABLE
class VehiculosTable extends SupabaseTable<VehiculosRow> {
  @override
  String get tableName => 'vehiculos';
  @override
  VehiculosRow mapRow(Map<String, dynamic> data) => VehiculosRow(data);
}

class VehiculosRow {
  VehiculosRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  String? get vehiculoCodigo => data['vehiculo_codigo'];
  double? get capacidadKg => data['capacidad_kg']?.toDouble();
  int? get capacidadTambores => data['capacidad_tambores'];
}

// APICULTORES TABLE
class ApicultoresTable extends SupabaseTable<ApicultoresRow> {
  @override
  String get tableName => 'apicultores';
  @override
  ApicultoresRow mapRow(Map<String, dynamic> data) => ApicultoresRow(data);
}

class ApicultoresRow {
  ApicultoresRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  String? get nombre => data['nombre'];
  String? get cuit => data['cuit'];
  String? get telefono => data['telefono'];
  String? get localidad => data['localidad'];
}

// REMITOS TABLE
class RemitosTable extends SupabaseTable<RemitosRow> {
  @override
  String get tableName => 'remitos';
  @override
  RemitosRow mapRow(Map<String, dynamic> data) => RemitosRow(data);
}

class RemitosRow {
  RemitosRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  String? get remitoCodigo => data['remito_codigo']; // ID legible, ej: REM-2024-001
  String? get paradaId => data['parada_id'];
  DateTime? get fecha => DateTime.tryParse(data['fecha'] ?? '');
  String? get firmaUrl => data['firma_url'];
  String? get pdfUrl => data['pdf_url'];
}

// PESAJES TABLE
class PesajesTable extends SupabaseTable<PesajesRow> {
  @override
  String get tableName => 'pesajes';
  @override
  PesajesRow mapRow(Map<String, dynamic> data) => PesajesRow(data);
}

class PesajesRow {
  PesajesRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  String? get paradaId => data['parada_id'];
  String? get senasaId => data['senasa_id'];
  double? get pesoBruto => data['peso_bruto']?.toDouble();
  double? get tara => data['tara']?.toDouble();
  double? get pesoNeto => data['peso_neto']?.toDouble();
}

// NECESIDADES TABLE
class NecesidadesTable extends SupabaseTable<NecesidadesRow> {
  @override
  String get tableName => 'necesidades';
  @override
  NecesidadesRow mapRow(Map<String, dynamic> data) => NecesidadesRow(data);
}

class NecesidadesRow {
  NecesidadesRow(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id'];
  String? get apicultorId => data['apicultor_id'];
  String? get producto => data['producto'];
  double? get cantidad => data['cantidad']?.toDouble();
  String? get tipo => data['tipo']; // Recolección / Distribución
  String? get estado => data['estado']; // Pendiente / En Ruta / Completado
  DateTime? get createdAt => DateTime.tryParse(data['created_at'] ?? '');
}

