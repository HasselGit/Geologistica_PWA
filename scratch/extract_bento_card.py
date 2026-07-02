import os
import re

# 1. Read homepage.dart
with open('lib/pages/homepage.dart', 'r', encoding='utf-8') as f:
    homepage_content = f.read()

# Extract SparklinePainter
sparkline_painter_match = re.search(r'class SparklinePainter extends CustomPainter \{.*?\n\}', homepage_content, re.DOTALL)
sparkline_painter = sparkline_painter_match.group(0) if sparkline_painter_match else ""

# Extract _BentoCardWidget and its state
bento_card_match = re.search(r'class _BentoCardWidget extends StatefulWidget \{.*?class _BentoCardWidgetState extends State<_BentoCardWidget> \{.*?^\}', homepage_content, re.DOTALL | re.MULTILINE)
bento_card = bento_card_match.group(0) if bento_card_match else ""

# Make them public
bento_card = bento_card.replace('_BentoCardWidget', 'GeoBentoCard')

bento_card_file_content = f"""import 'package:flutter/material.dart';
import '../backend/design_tokens.dart';
import 'dart:ui';

{bento_card}

{sparkline_painter}
"""

with open('lib/widgets/geo_bento_card.dart', 'w', encoding='utf-8') as f:
    f.write(bento_card_file_content)

# 2. Update homepage.dart
homepage_content = homepage_content.replace(bento_card, '')
homepage_content = homepage_content.replace(sparkline_painter, '')
# Add import
homepage_content = homepage_content.replace("import '../widgets/geo_sidebar.dart';", "import '../widgets/geo_sidebar.dart';\nimport '../widgets/geo_bento_card.dart';")
# Replace usages
homepage_content = homepage_content.replace('_BentoCardWidget', 'GeoBentoCard')

with open('lib/pages/homepage.dart', 'w', encoding='utf-8') as f:
    f.write(homepage_content)

# 3. Update gerentehome.dart
with open('lib/pages/gerentehome.dart', 'r', encoding='utf-8') as f:
    gerente_content = f.read()

# Add import
gerente_content = gerente_content.replace("import '../widgets/geo_sidebar.dart';", "import '../widgets/geo_sidebar.dart';\nimport '../widgets/geo_bento_card.dart';")

# Replace KPI methods with GeoBentoCard invocations
new_kpis_row = """              Row(
                children: [
                  Expanded(
                    child: GeoBentoCard(
                      title: 'CARGA EN VIAJE',
                      value: '${_totalKg.toStringAsFixed(0)} KG',
                      trend: 'En vivo',
                      iconWidget: const Icon(Icons.balance_rounded, color: DesignTokens.secondary, size: 24),
                      accentColor: DesignTokens.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GeoBentoCard(
                      title: 'VIAJES ACTIVOS',
                      value: '$cursCount',
                      trend: '$pendCount en espera',
                      iconWidget: const Icon(Icons.local_shipping_rounded, color: Colors.green, size: 24),
                      accentColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GeoBentoCard(
                      title: 'STOCK TAMBORES',
                      value: '$_tamboresStock',
                      trend: 'Unidades',
                      iconWidget: const Icon(Icons.inventory_2_rounded, color: Colors.redAccent, size: 24),
                      accentColor: Colors.redAccent,
                      sparklineData: const [5,2,8,4,9,3,7,2,6,4,8],
                    ),
                  ),
                ],
              ),"""

gerente_content = re.sub(r'Row\(\s*children:\s*\[\s*Expanded\(flex: 5, child: _buildKPIHighEndWeight\(_totalKg\)\),.*?\]\s*,\s*\),', new_kpis_row, gerente_content, flags=re.DOTALL)

# Delete old methods
gerente_content = re.sub(r'Widget _buildKPIHighEndWeight\(double kg\) \{.*?\n  \}', '', gerente_content, flags=re.DOTALL)
gerente_content = re.sub(r'Widget _buildKPIHighEndTrips\(int enCurso, int pendientes, int terminados\) \{.*?\n  \}', '', gerente_content, flags=re.DOTALL)
gerente_content = re.sub(r'Widget _buildKPIHighEndStock\(int stock\) \{.*?\n  \}', '', gerente_content, flags=re.DOTALL)

with open('lib/pages/gerentehome.dart', 'w', encoding='utf-8') as f:
    f.write(gerente_content)

print("Done")
