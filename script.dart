import 'dart:io';

void main() {
  final file = File('lib/pages/pesajes_page.dart');
  var content = file.readAsStringSync();

  // 1. Add apicultor_id to _fetchData
  content = content.replaceAll(
    '''
        final apicId = firstItem['apicultor_id']?.toString() ?? 'S/D';

        return {
          'parada_id': paradaId,
          'viaje_id': firstItem['viaje_id']?.toString() ?? '',
          'viaje_codigo': viaje['viaje_codigo'] ?? 'V-S/N',
          'viaje_fecha': viaje['fecha'],
          'apicultor': parada['ubicacion'] ?? parada['localidad'] ?? apicId,''',
    '''
        final apicId = firstItem['apicultor_id']?.toString() ?? 'S/D';

        return {
          'parada_id': paradaId,
          'viaje_id': firstItem['viaje_id']?.toString() ?? '',
          'viaje_codigo': viaje['viaje_codigo'] ?? 'V-S/N',
          'viaje_fecha': viaje['fecha'],
          'apicultor_id': apicId,
          'apicultor': parada['ubicacion'] ?? parada['localidad'] ?? apicId,'''
  );

  // 2. Add fechaStr and viajeId to mobile card
  content = content.replaceAll(
    '''
    final totalNeto = (grupo['total_neto'] as double?) ?? 0.0;
    final totalBruto = (grupo['total_bruto'] as double?) ?? 0.0;

    return Container(''',
    '''
    final totalNeto = (grupo['total_neto'] as double?) ?? 0.0;
    final totalBruto = (grupo['total_bruto'] as double?) ?? 0.0;
    final fechaStr = grupo['viaje_fecha'] != null
        ? DateFormat('dd/MM/yy').format(DateTime.tryParse(grupo['viaje_fecha'].toString()) ?? DateTime.now())
        : '--/--/--';
    final viajeId = grupo['viaje_id']?.toString() ?? '';

    return Container('''
  );

  // 3. Add InkWell to mobile card viajeCodigo and show Date
  content = content.replaceAll(
    '''
                        const SizedBox(width: 6),
                        Text(
                          viajeCodigo,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF08201A),
                          ),
                        ),
                        const Spacer(),''',
    '''
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => context.push('/viajedetalle?viajeId=\'),
                          child: Text(
                            viajeCodigo,
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: DesignTokens.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(fechaStr, style: TextStyle(fontSize: 11, color: DesignTokens.primary.withOpacity(0.5))),
                        const Spacer(),'''
  );

  // 4. Update the 'Aplicar Filtros' button
  content = content.replaceAll(
    '''
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC68E17),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.filter_list_rounded, size: 16),
                                label: const Text('Aplicar Filtros', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold)),
                                onPressed: () {},
                              ),''',
    '''
                              child: ElevatedButton.icon(
                                style: DesignTokens.primaryButtonStyle,
                                icon: const Icon(Icons.filter_list_rounded, size: 16),
                                label: const Text('Aplicar Filtros', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 13)),
                                onPressed: () => _applyFilters(),
                              ),'''
  );

  // 5. Add FECHA column to Desktop DataTable
  content = content.replaceAll(
    '''
                                        columns: const [
                                          DataColumn(label: Text('VIAJE', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                          DataColumn(label: Text('APICULTOR / LOC',''',
    '''
                                        columns: const [
                                          DataColumn(label: Text('VIAJE', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                          DataColumn(label: Text('FECHA', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                          DataColumn(label: Text('APICULTOR / LOC','''
  );

  // 6. Update mapping variables for Desktop DataTable
  content = content.replaceAll(
    '''
                                          final viajeCode = g['viaje_codigo'] as String;
                                          final apicultor = g['apicultor'] as String;
                                          final localidad = g['localidad'] as String;''',
    '''
                                          final viajeCode = g['viaje_codigo'] as String;
                                          final viajeId = g['viaje_id']?.toString() ?? '';
                                          final fechaStr = g['viaje_fecha'] != null ? DateFormat('dd/MM/yy').format(DateTime.tryParse(g['viaje_fecha'].toString()) ?? DateTime.now()) : '--/--/--';
                                          final apicultor = g['apicultor'] as String;
                                          final localidad = g['localidad'] as String;'''
  );

  // 7. Update Desktop DataTable cells (adding FECHA cell, wrapping VIAJE and APICULTOR in InkWells)
  content = content.replaceAll(
    '''
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(viajeCode, style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600, color: Color(0xFF08201A)))),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(apicultor, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF08201A))),
                                                  Text(localidad, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: const Color(0xFF08201A).withOpacity(0.5))),
                                                ],
                                              )),''',
    '''
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                InkWell(
                                                  onTap: () => context.push('/viajedetalle?viajeId=\'),
                                                  child: Text(viajeCode, style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600, color: DesignTokens.primary, decoration: TextDecoration.underline)),
                                                ),
                                              ),
                                              DataCell(Text(fechaStr, style: const TextStyle(fontFamily: 'JetBrains Mono', color: Colors.black54))),
                                              DataCell(InkWell(
                                                onTap: () => context.push('/apicultores'),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(apicultor, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13, color: DesignTokens.primary, decoration: TextDecoration.underline)),
                                                    Text(localidad, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: const Color(0xFF08201A).withOpacity(0.5))),
                                                  ],
                                                ),
                                              )),'''
  );

  file.writeAsStringSync(content);
  print('done');
}
