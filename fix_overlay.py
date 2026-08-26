import os

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    old_stack = '''          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 72.0),
                  child: widget.desktopBody,
                ),
              ),
              SafeArea(child: _buildDesktopSidebar()),
            ],
          ),'''
          
    new_stack = '''          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 72.0),
                  child: widget.desktopBody,
                ),
              ),
              if (_isSidebarExpanded)
                GestureDetector(
                  onTap: () => setState(() => _isSidebarExpanded = false),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              SafeArea(child: _buildDesktopSidebar()),
            ],
          ),'''
          
    content = content.replace(old_stack, new_stack)
    old_stack_r = old_stack.replace('\n', '\r\n')
    new_stack_r = new_stack.replace('\n', '\r\n')
    content = content.replace(old_stack_r, new_stack_r)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file('frontend/attendance_app/lib/widgets/teacher_web_layout.dart')
fix_file('frontend/attendance_app/lib/widgets/admin_web_layout.dart')
print('Done!')
