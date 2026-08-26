import os

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Fade transition
    content = content.replace('return child;\n      },\n      transitionDuration: Duration.zero,\n      reverseTransitionDuration: Duration.zero,', 'return FadeTransition(opacity: animation, child: child);\n      },\n      transitionDuration: const Duration(milliseconds: 150),\n      reverseTransitionDuration: const Duration(milliseconds: 150),')
    content = content.replace('return child;\r\n      },\r\n      transitionDuration: Duration.zero,\r\n      reverseTransitionDuration: Duration.zero,', 'return FadeTransition(opacity: animation, child: child);\n      },\n      transitionDuration: const Duration(milliseconds: 150),\n      reverseTransitionDuration: const Duration(milliseconds: 150),')

    # 2. Add GestureDetector start
    content = content.replace('Widget _buildDesktopSidebar() {\n    return AnimatedContainer(', 'Widget _buildDesktopSidebar() {\n    return GestureDetector(\n      onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),\n      child: AnimatedContainer(')
    content = content.replace('Widget _buildDesktopSidebar() {\r\n    return AnimatedContainer(', 'Widget _buildDesktopSidebar() {\n    return GestureDetector(\n      onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),\n      child: AnimatedContainer(')

    # 3. Add GestureDetector end
    old_end = "_buildSidebarItem(Icons.logout, 'Logout'),\n          const SizedBox(height: 20),\n        ],\n      ),\n    );\n  }\n\n  @override"
    new_end = "_buildSidebarItem(Icons.logout, 'Logout'),\n          const SizedBox(height: 20),\n        ],\n      ),\n      ),\n    );\n  }\n\n  @override"
    content = content.replace(old_end, new_end)
    
    old_end_r = "_buildSidebarItem(Icons.logout, 'Logout'),\r\n          const SizedBox(height: 20),\r\n        ],\r\n      ),\r\n    );\r\n  }\r\n\r\n  @override"
    content = content.replace(old_end_r, new_end)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file('frontend/attendance_app/lib/widgets/teacher_web_layout.dart')
fix_file('frontend/attendance_app/lib/widgets/admin_web_layout.dart')
print('Done!')
