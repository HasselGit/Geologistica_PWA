import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';

class RegistroPesajePremiumWidget extends StatefulWidget {
  final Map<String, dynamic>? pesajeData;
  const RegistroPesajePremiumWidget({super.key, this.pesajeData});

  @override
  State<RegistroPesajePremiumWidget> createState() => _RegistroPesajePremiumWidgetState();
}

class _RegistroPesajePremiumWidgetState extends State<RegistroPesajePremiumWidget> {
  bool _loading = false;
  List<Map<String, dynamic>> _tambores = [];
  
  @override
  void initState() {
    super.initState();
    _fetchTambores();
  }

  Future<void> _fetchTambores() async {
    // Mocking data based on image for now, but connecting to DB
    setState(() => _loading = true);
    try {
      // En una app real, aquí filtraríamos por un ID de lote o remito
      final data = await Supabase.instance.client
          .from('pesajes')
          .select('*')
          .limit(10)
          .order('created_at', ascending: false);
      
      setState(() {
        _tambores = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Datos de ejemplo basados en el mockup
    final apicultorNombre = widget.pesajeData?['apicultor'] ?? 'Julian Thorne';
    final localidad = widget.pesajeData?['localidad'] ?? 'Blue Mountains';
    final nroPesaje = widget.pesajeData?['codigo'] ?? '#PES-8829';
    final fecha = widget.pesajeData?['fecha'] ?? '15 de Octubre, 2023';
    
    // Cálculos
    double totalBruto = _tambores.fold(0, (sum, item) => sum + (double.tryParse(item['peso_bruto']?.toString() ?? '0') ?? 0));
    double totalTara = _tambores.fold(0, (sum, item) => sum + (double.tryParse(item['tara']?.toString() ?? '0') ?? 0));
    double totalNeto = totalBruto - totalTara;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hive_outlined, size: 24, color: DesignTokens.primary),
            const SizedBox(width: 8),
            Text('APIARY LOGISTICS', 
              style: DesignTokens.headlineStyle().copyWith(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: DesignTokens.primary), onPressed: () {}),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(radius: 14, backgroundImage: NetworkImage('https://via.placeholder.com/150')),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Registro de Pesajes', style: DesignTokens.headlineStyle().copyWith(fontSize: 28, fontWeight: FontWeight.w900)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('EN CURSO', style: TextStyle(color: Color(0xFFC68E17), fontWeight: FontWeight.w800, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(fecha, style: DesignTokens.bodyStyle().copyWith(color: Colors.black54, fontSize: 14)),
                  ],
                ),
                Text(nroPesaje, style: DesignTokens.headlineStyle().copyWith(fontSize: 18, color: const Color(0xFF424846))),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildInfoCard(Icons.person_outline, 'APICULTOR', apicultorNombre)),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard(Icons.location_on_outlined, 'LOCALIDAD', localidad)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildTotalCol('BRUTO', '${NumberFormat('#,###', 'es_AR').format(totalBruto)} kg')),
                Container(width: 1, height: 40, color: Colors.black12),
                Expanded(child: _buildTotalCol('TARA', '${NumberFormat('#,###', 'es_AR').format(totalTara)} kg')),
                Container(width: 1, height: 40, color: Colors.black12),
                Expanded(child: _buildTotalCol('NETO', '${NumberFormat('#,###', 'es_AR').format(totalNeto)} kg', isHighlighted: true)),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Detalle de Tambores', style: DesignTokens.headlineStyle().copyWith(fontSize: 20)),
                Text('${_tambores.length} ITEMS', style: DesignTokens.labelStyle().copyWith(color: Colors.black38, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTamboresTable(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width - 40,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_circle_outline, color: DesignTokens.primary),
          label: const Text('Añadir Nuevo Registro', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107).withOpacity(0.8),
            foregroundColor: DesignTokens.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: Colors.black38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: Colors.black38)),
                Text(value, style: DesignTokens.bodyStyle().copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF424846)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCol(String label, String value, {bool isHighlighted = false}) {
    return Column(
      children: [
        Text(label, style: DesignTokens.labelStyle().copyWith(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(value, style: DesignTokens.headlineStyle().copyWith(
          fontSize: 18, 
          color: isHighlighted ? const Color(0xFFC68E17) : const Color(0xFF424846),
          fontWeight: isHighlighted ? FontWeight.w900 : FontWeight.w500
        )),
      ],
    );
  }

  Widget _buildTamboresTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          if (_loading) 
            const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
          else if (_tambores.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text('No hay tambores registrados'))
          else
            ..._tambores.asMap().entries.map((entry) => _buildTableRow(entry.value, entry.key + 1)).toList(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Expanded(flex: 1, child: Text('ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38))),
          const Expanded(flex: 3, child: Text('Cód. SENASA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38))),
          _buildSmallHeader('Bruto'),
          _buildSmallHeader('Tara'),
          _buildSmallHeader('Neto'),
        ],
      ),
    );
  }

  Widget _buildSmallHeader(String text) {
    return Expanded(flex: 2, child: Text(text, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38)));
  }

  Widget _buildTableRow(Map<String, dynamic> item, int index) {
    final bruto = double.tryParse(item['peso_bruto']?.toString() ?? '0') ?? 0;
    final tara = double.tryParse(item['tara']?.toString() ?? '0') ?? 0;
    final neto = bruto - tara;
    final senasa = item['senasa_id'] ?? item['nro_tambor'] ?? 'S/D';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('TCM-$index', style: DesignTokens.bodyStyle().copyWith(fontSize: 12, color: Colors.black54))),
          Expanded(flex: 3, child: Row(
            children: [
              Text(senasa, style: DesignTokens.bodyStyle().copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF424846))),
              const SizedBox(width: 4),
              const Icon(Icons.verified_outlined, size: 14, color: Color(0xFFC68E17)),
            ],
          )),
          _buildCell('${NumberFormat('#,###', 'es_AR').format(bruto)} kg'),
          _buildCell('${NumberFormat('#,###', 'es_AR').format(tara)} kg'),
          _buildCell('${NumberFormat('#,###', 'es_AR').format(neto)} kg', isBold: true),
        ],
      ),
    );
  }

  Widget _buildCell(String text, {bool isBold = false}) {
    return Expanded(
      flex: 2, 
      child: Text(text, textAlign: TextAlign.right, style: DesignTokens.bodyStyle().copyWith(
        fontSize: 12, 
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: const Color(0xFF424846)
      ))
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.local_shipping_outlined, 'FLEET'),
          _buildNavItem(Icons.location_on_outlined, 'DRIVERS'),
          _buildNavItem(Icons.scale_outlined, 'PESAJES', active: true),
          _buildNavItem(Icons.notifications_none_rounded, 'ALERTS'),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, {bool active = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? const Color(0xFFC68E17) : Colors.black26, size: 24),
        const SizedBox(height: 4),
        Text(label, style: DesignTokens.labelStyle().copyWith(
          fontSize: 8, 
          fontWeight: FontWeight.w900,
          color: active ? const Color(0xFFC68E17) : Colors.black26
        )),
      ],
    );
  }
}
