import os

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Fix _fadeRoute
    old_fade = '''  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }'''
    
    new_fade = '''  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    );
  }'''
    
    content = content.replace(old_fade, new_fade)
    
    # 2. Fix AnimatedContainer
    old_sidebar_start = '''  Widget _buildDesktopSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),'''
      
    new_sidebar_start = '''  Widget _buildDesktopSidebar() {
    return GestureDetector(
      onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),'''
        
    content = content.replace(old_sidebar_start, new_sidebar_start)
    
    old_sidebar_end = '''            _buildSidebarItem(Icons.logout, 'Logout'),
            const SizedBox(height: 20),
          ],
        ),
      );
    }'''
    
    new_sidebar_end = '''            _buildSidebarItem(Icons.logout, 'Logout'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }'''
  
    content = content.replace(old_sidebar_end, new_sidebar_end)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file('frontend/attendance_app/lib/widgets/teacher_web_layout.dart')
fix_file('frontend/attendance_app/lib/widgets/admin_web_layout.dart')
print('Done!')
