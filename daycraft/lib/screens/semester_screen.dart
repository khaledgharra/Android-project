import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SemesterScreen extends StatefulWidget {
  /// If true, the user cannot dismiss without selecting a semester (first-launch flow).
  final bool required;

  const SemesterScreen({super.key, this.required = false});

  @override
  State<SemesterScreen> createState() => _SemesterScreenState();
}

class _SemesterScreenState extends State<SemesterScreen> {
  List<Map<String, dynamic>> _semesters = [];
  bool _isLoading = true;
  String? _activeSemesterId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      StorageService.loadSemesters(),
      StorageService.loadActiveSemesterId(),
    ]);
    if (!mounted) return;
    setState(() {
      _semesters = results[0] as List<Map<String, dynamic>>;
      _activeSemesterId = results[1] as String?;
      _isLoading = false;
    });
  }

  Future<void> _selectSemester(Map<String, dynamic> sem) async {
    final id = sem['id'] as String;
    StorageService.currentSemesterId = id;
    await StorageService.saveActiveSemesterId(id);
    if (!mounted) return;
    Navigator.of(context).pop(sem);
  }

  void _showCreateSheet() {
    final ctrl = TextEditingController();
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    final suggestion = month >= 8 ? 'Fall $year' : 'Spring $year';
    ctrl.text = suggestion;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Semester',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Semester name',
                  hintText: 'e.g. Fall 2025',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final name = ctrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final id = await StorageService.createSemester(name);
                    if (id == null) {
                      if (mounted) setState(() => _isLoading = false);
                      return;
                    }
                    final newSem = {'id': id, 'name': name};
                    await _selectSemester(newSem);
                  },
                  child: const Text('Create & Select',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> sem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Semester'),
        content: Text('Delete "${sem['name']}" and all its data? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    await StorageService.deleteSemester(sem['id'] as String);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !widget.required || _activeSemesterId != null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Semesters'),
          automaticallyImplyLeading: !widget.required || _activeSemesterId != null,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _semesters.isEmpty
                ? _buildEmpty()
                : _buildList(cs),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateSheet,
          backgroundColor: const Color(0xFF7B61FF),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Semester', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No semesters yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Create your first semester to get started.',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme cs) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _semesters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final sem = _semesters[i];
        final isActive = sem['id'] == _activeSemesterId;
        return ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          tileColor: isActive
              ? const Color(0xFF7B61FF).withOpacity(0.12)
              : cs.surfaceContainerHighest,
          leading: CircleAvatar(
            backgroundColor: isActive ? const Color(0xFF7B61FF) : Colors.grey.shade300,
            child: Icon(
              Icons.school_rounded,
              color: isActive ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ),
          title: Text(sem['name'] as String,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF7B61FF) : null,
              )),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('Active',
                      style: TextStyle(
                          color: Color(0xFF7B61FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: () => _confirmDelete(sem),
              ),
            ],
          ),
          onTap: () => _selectSemester(sem),
        );
      },
    );
  }
}
