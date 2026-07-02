import sys

with open('lib/pages/homepage.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "Widget _buildSidebar(BuildContext context) {" in line:
        skip = True
    elif "Widget _sidebarItem(IconData icon" in line:
        skip = True
    elif "Widget _buildSyncMonitor() {" in line:
        skip = True
        
    if "Widget _buildSyncMonitorFloating() {" in line:
        skip = False

    if not skip:
        new_lines.append(line)

with open('lib/pages/homepage.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
