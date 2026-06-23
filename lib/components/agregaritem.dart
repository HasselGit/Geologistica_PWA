import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/design_tokens.dart';
import '../backend/supabase_service.dart';

class AgregarItemWidget extends StatefulWidget {
  const AgregarItemWidget({super.key, required this.paradaId, this.viajeId});
  final String? paradaId;
  final String? viajeId;

  @override
  State<AgregarItemWidget> createState() => _AgregarItemWidgetState();
}

class _AgregarItemWidgetState extends State<AgregarItemWidget> {
  final _textController = TextEditingController();
  String? _selectedProduct;
  String? _selectedUnit;
  String _tipoMovimiento = 'Recolección'; // 'Recolección' (Retira) o 'Distribución' (Entrega)
  List<Map<String, dynamic>> _productos = [];
  List<String> _productosEnCamion = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    try {
      final response = await SupabaseService().getProductos();
      List<String> inTruck = [];
      if (widget.viajeId != null && widget.viajeId!.isNotEmpty) {
        final cargas = await Supabase.instance.client
            .from('cargas')
            .select('id, carga_items(producto_codigo, cantidad)')
            .eq('viaje_id', widget.viajeId!)
            .or('estado.eq.Terminado,estado.eq.Terminada');
            
        for (var c in cargas) {
          var items = c['carga_items'] as List? ?? [];
          if (items.isEmpty) {
            try {
              final directItems = await Supabase.instance.client
                  .from('carga_items')
                  .select('producto_codigo, cantidad')
                  .eq('carga_id', c['id']);
              items = directItems;
            } catch (fallbackErr) {
              print('AgregarItem: Fallback error querying carga_items directly: $fallbackErr');
            }
          }
          for (var it in items) {
             inTruck.add(it['producto_codigo'].toString().trim());
          }
        }
      }

      setState(() {
        _productos = List<Map<String, dynamic>>.from(response);
        _productosEnCamion = inTruck;
      });
    } catch (e) {
      print('Error cargando productos: $e');
    }
  }

  double _getProductWeight(String code) {
    final p = _productos.firstWhere(
      (prod) => prod['codigo']?.toString().toUpperCase() == code.toUpperCase(),
      orElse: () => {},
    );
    if (p.isNotEmpty && p['peso_unit_kg'] != null) {
      return (p['peso_unit_kg'] as num).toDouble();
    }
    // Fallbacks estándar
    if (code == 'TCM' || code.contains('TAMBOR')) return 300.0;
    if ((code.startsWith('T') && code != 'TV' && code != 'TE') || code.contains('VACIO') || code.contains('VACÍO')) return 20.0;
    if (code == 'AZ') return 50.0;
    return 1.0;
  }

  Future<double> _calcularStockEnTransito(String productoCodigo) async {
    if (widget.viajeId == null || widget.viajeId!.isEmpty) return 0.0;

    double stock = 0.0;

    // 1. Sumar stock inicial cargado desde Cargas
    try {
      final cargas = await Supabase.instance.client
          .from('cargas')
          .select('carga_items(producto_codigo, cantidad)')
          .eq('viaje_id', widget.viajeId!)
          .or('estado.eq.Terminado,estado.eq.Terminada');
          
      for (var c in cargas) {
        final items = c['carga_items'] as List? ?? [];
        for (var it in items) {
          if (it['producto_codigo'].toString().trim().toUpperCase() == productoCodigo.toUpperCase()) {
            stock += (it['cantidad'] ?? 0).toDouble();
          }
        }
      }
    } catch (e) {
      print('Error al calcular stock inicial de carga: $e');
    }

    // 2. Ajustar por paradas finalizadas (restar entregas, sumar recolecciones)
    try {
      final paradas = await Supabase.instance.client
          .from('paradas')
          .select('tipo, estado, parada_items(producto_codigo, cantidad)')
          .eq('viaje_id', widget.viajeId!)
          .eq('estado', 'Terminado');

      for (var p in paradas) {
        final String tipo = p['tipo'] ?? '';
        final items = p['parada_items'] as List? ?? [];
        for (var it in items) {
          if (it['producto_codigo'].toString().trim().toUpperCase() == productoCodigo.toUpperCase()) {
            final double cant = (it['cantidad'] ?? 0).toDouble();
            if (tipo == 'Distribución') {
              stock -= cant;
            } else if (tipo == 'Recolección') {
              stock += cant;
            }
          }
        }
      }
    } catch (e) {
      print('Error al calcular ajustes de paradas para stock: $e');
    }

    return stock;
  }

  Future<bool> _validarCapacidadCamion(String productoCodigo, double cantidadAAnadir, String tipoMovimiento) async {
    if (widget.viajeId == null || widget.viajeId!.isEmpty) return true; // Si no hay viaje, no hay límite

    try {
      // 1. Obtener la capacidad del vehículo
      final viaje = await Supabase.instance.client
          .from('viajes')
          .select('vehiculos:vehiculo_codigo(capacidad_kg)')
          .eq('id', widget.viajeId!)
          .maybeSingle();
      if (viaje == null) return true;
      final double capKg = (viaje['vehiculos']?['capacidad_kg'] ?? 0).toDouble();
      if (capKg <= 0) return true; // Sin límite definido

      // 2. Calcular el peso actual del camión usando la fórmula dinámica
      double pesoActual = 0.0;

      // Carga inicial
      final cargas = await Supabase.instance.client
          .from('cargas')
          .select('carga_items(producto_codigo, cantidad)')
          .eq('viaje_id', widget.viajeId!)
          .or('estado.eq.Terminado,estado.eq.Terminada');
          
      for (var c in cargas) {
        final items = c['carga_items'] as List? ?? [];
        for (var it in items) {
          final String prod = it['producto_codigo'].toString().trim().toUpperCase();
          final double cant = (it['cantidad'] ?? 0).toDouble();
          pesoActual += cant * _getProductWeight(prod);
        }
      }

      // Paradas finalizadas
      final paradas = await Supabase.instance.client
          .from('paradas')
          .select('tipo, estado, parada_items(producto_codigo, cantidad)')
          .eq('viaje_id', widget.viajeId!)
          .eq('estado', 'Terminado');

      for (var p in paradas) {
        final String tipo = p['tipo'] ?? '';
        final items = p['parada_items'] as List? ?? [];
        for (var it in items) {
          final String prod = it['producto_codigo'].toString().trim().toUpperCase();
          final double cant = (it['cantidad'] ?? 0).toDouble();
          final double itemWeight = cant * _getProductWeight(prod);

          if (tipo == 'Distribución') {
            pesoActual -= itemWeight;
          } else if (tipo == 'Recolección') {
            pesoActual += itemWeight;
          }
        }
      }

      // 3. Calcular el peso del nuevo ítem que se quiere agregar
      final double nuevoPeso = cantidadAAnadir * _getProductWeight(productoCodigo);

      double pesoProyectado = pesoActual;
      if (tipoMovimiento == 'Recolección') {
        pesoProyectado += nuevoPeso;
      } else if (tipoMovimiento == 'Distribución') {
        pesoProyectado -= nuevoPeso;
      }

      if (pesoProyectado > capKg) {
        return false;
      }
    } catch (e) {
      print('Error al validar capacidad del camión: $e');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text(
            'Agregar Producto / Insumo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: DesignTokens.primary, fontFamily: 'Manrope'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Seleccioná el tipo de operación y el producto.',
            style: TextStyle(fontSize: 13, color: DesignTokens.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Selector de Tipo de Movimiento
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: DesignTokens.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipoMovimiento = 'Recolección'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tipoMovimiento == 'Recolección' ? DesignTokens.secondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'RECOLECCIÓN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _tipoMovimiento == 'Recolección' ? Colors.white : DesignTokens.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipoMovimiento = 'Distribución'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tipoMovimiento == 'Distribución' ? DesignTokens.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'DISTRIBUCIÓN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _tipoMovimiento == 'Distribución' ? Colors.white : DesignTokens.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedProduct,
            hint: const Text('Buscar Producto...'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: DesignTokens.primary),
            decoration: InputDecoration(
              filled: true,
              fillColor: DesignTokens.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: _productos.where((p) {
              if (_tipoMovimiento == 'Distribución') {
                return _productosEnCamion.contains((p['codigo'] ?? '').toString().trim());
              }
              return true;
            }).map((prod) => DropdownMenuItem(
              value: prod['codigo']?.toString(),
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 100,
                child: Text(
                  prod['descripcion']?.toString() ?? '--',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            )).toList(),
            onChanged: (val) {
              setState(() {
                _selectedProduct = val;
                final p = _productos.firstWhere((element) => element['codigo'].toString() == val);
                _selectedUnit = p['unidad']?.toString() ?? 'Unidades';
              });
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            decoration: InputDecoration(
              labelText: _selectedUnit != null ? 'Cantidad ($_selectedUnit)' : 'Cantidad',
              filled: true,
              fillColor: DesignTokens.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.calculate_outlined, color: DesignTokens.primary),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: (_isSaving || _selectedProduct == null) ? null : () async {
                setState(() => _isSaving = true);
                try {
                  if (widget.paradaId != null && _selectedProduct != null) {
                    final double qty = double.tryParse(_textController.text) ?? 0.0;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor, ingresá una cantidad válida.'), backgroundColor: Colors.orangeAccent),
                      );
                      setState(() => _isSaving = false);
                      return;
                    }

                    // 1. Validar Stock en Tránsito si es Distribución
                    if (_tipoMovimiento == 'Distribución') {
                      final double stockDisponible = await _calcularStockEnTransito(_selectedProduct!);
                      if (qty > stockDisponible) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: No hay suficiente stock en el camión. Disponible: ${stockDisponible.round()} unidades.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        setState(() => _isSaving = false);
                        return;
                      }
                    }

                    // 2. Validar Capacidad del Camión
                    final bool pesoValido = await _validarCapacidadCamion(_selectedProduct!, qty, _tipoMovimiento);
                    if (!pesoValido) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error: Esta operación supera la capacidad máxima de carga del camión.'),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                      setState(() => _isSaving = false);
                      return;
                    }

                    // 3. Insert Item
                    final bool isTCM = _selectedProduct == 'TCM';
                    final String baseUnit = isTCM ? 'uni' : (_selectedUnit ?? 'Uni');
                    await Supabase.instance.client.from('parada_items').insert({
                      'parada_id': widget.paradaId,
                      'producto_codigo': _selectedProduct,
                      'cantidad': qty,
                      'unidad': '$baseUnit|$_tipoMovimiento',
                    });

                    // 2. Asegurar que el tipo de parada refleje la operación actual (puede convertirse en MIXTA)
                    final parada = await Supabase.instance.client.from('paradas')
                        .select('tipo')
                        .eq('id', widget.paradaId!)
                        .single();
                    
                    String currentTipo = (parada['tipo'] ?? '').toString().trim();
                    String newTipo = currentTipo;

                    if (_tipoMovimiento == 'Recolección') {
                      if (!currentTipo.toLowerCase().contains('recolec') && !currentTipo.toLowerCase().contains('mixta')) {
                        newTipo = currentTipo.isEmpty ? 'Recolección' : 'MIXTA';
                      }
                    } else if (_tipoMovimiento == 'Distribución') {
                      if (!currentTipo.toLowerCase().contains('distrib') && !currentTipo.toLowerCase().contains('mixta')) {
                        newTipo = currentTipo.isEmpty ? 'Distribución' : 'MIXTA';
                      }
                    }

                    if (newTipo != currentTipo) {
                      try {
                        await Supabase.instance.client.from('paradas')
                            .update({'tipo': newTipo})
                            .eq('id', widget.paradaId!);
                      } catch (e) {
                        print('Aviso: no se pudo actualizar el tipo de parada a MIXTA: $e');
                        // Ignoramos el error para no colgar la UI si hay RLS
                      }
                    }

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Text('GUARDAR ITEM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
