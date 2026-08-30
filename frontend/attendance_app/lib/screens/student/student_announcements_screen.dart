import 'package:flutter/material.dart';
import '../../services/announcement_service.dart';

class StudentAnnouncementsScreen extends StatefulWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  State<StudentAnnouncementsScreen> createState() => _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState extends State<StudentAnnouncementsScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _filteredAnnouncements = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'All'; // 'All', 'class', 'individual', 'Urgent'

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final announcements = await _announcementService.getAnnouncements();
      setState(() {
        _announcements = announcements;
        _filteredAnnouncements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading announcements: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAnnouncements = _announcements.where((ann) {
        final matchesSearch = ann['title'].toString().toLowerCase().contains(query) ||
            ann['content'].toString().toLowerCase().contains(query);
        
        bool matchesFilter = true;
        if (_filterType == 'class') {
          matchesFilter = ann['target_type'] == 'class' || ann['target_type'] == 'low_attendance';
        } else if (_filterType == 'individual') {
          matchesFilter = ann['target_type'] == 'individual';
        } else if (_filterType == 'Urgent') {
          matchesFilter = ann['is_urgent'] == true;
        }

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Announcements'),
        backgroundColor: const Color(0xFF1E5B53),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnnouncements,
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF4F6F6),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search notices...',
                        prefixIcon: const Icon(Icons.search),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _filterType,
                      underline: const SizedBox(),
                      items: ['All', 'class', 'individual', 'Urgent'].map((String val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(
                            val == 'class' ? 'Class' : val == 'individual' ? 'Private' : val,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _filterType = val;
                          });
                          _filterList();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Announcements list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredAnnouncements.isEmpty
                        ? const Center(child: Text('No announcements found.'))
                        : ListView.builder(
                            itemCount: _filteredAnnouncements.length,
                            itemBuilder: (context, index) {
                              final ann = _filteredAnnouncements[index];
                              return _buildAnnouncementCard(ann);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> ann) {
    final String senderName = ann['sender_name'] ?? 'Teacher';
    final String initial = senderName.isNotEmpty ? senderName[0].toUpperCase() : 'T';

    // Tag UI
    Color tagColor = Colors.grey;
    String tagLabel = 'Class';
    if (ann['target_type'] == 'individual') {
      tagColor = Colors.blue;
      tagLabel = 'Private';
    } else if (ann['target_type'] == 'low_attendance') {
      tagColor = Colors.orange;
      tagLabel = 'Attendance Notice';
    } else if (ann['class_code'] != null) {
      tagLabel = ann['class_code'];
      tagColor = const Color(0xFF1E5B53);
    }

    final bool isUrgent = ann['is_urgent'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isUrgent ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        key: ValueKey('student_announcement_${ann['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isUrgent ? Colors.red.shade100 : const Color(0xFFE2EFEA),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: isUrgent ? Colors.red : const Color(0xFF1E5B53),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            senderName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          if (isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                              child: const Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: tagColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              tagLabel,
                              style: TextStyle(color: tagColor, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ann['created_at'] != null
                            ? DateTime.parse(ann['created_at']).toLocal().toString().substring(0, 16)
                            : '',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ann['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              ann['content'] ?? '',
              style: const TextStyle(color: Colors.black87, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
