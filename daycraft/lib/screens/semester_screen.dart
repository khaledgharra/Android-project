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
    DateTime? endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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
                  const SizedBox(height: 12),
                  // End date picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: endDate ?? DateTime.now().add(const Duration(days: 120)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                        helpText: 'SEMESTER END DATE',
                      );
                      if (picked != null) setSheetState(() => endDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: endDate != null ? const Color(0xFF7B61FF) : Colors.grey.shade400,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.event_rounded, size: 18,
                            color: endDate != null ? const Color(0xFF7B61FF) : Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            endDate != null
                                ? 'Ends ${_fmtDate(endDate!)}'
                                : 'Set end date (optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: endDate != null ? const Color(0xFF7B61FF) : Colors.grey,
                            ),
                          ),
                        ),
                        if (endDate != null)
                          GestureDetector(
                            onTap: () => setSheetState(() => endDate = null),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          ),
                      ]),
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
                        final endDateStr = endDate != null
                            ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                            : null;
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);
                        final id = await StorageService.createSemester(name, endDate: endDateStr);
                        if (id == null) {
                          if (mounted) setState(() => _isLoading = false);
                          return;
                        }
                        final newSem = <String, dynamic>{'id': id, 'name': name};
                        if (endDateStr != null) newSem['endDate'] = endDateStr;
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
      },
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _showEditEndDate(Map<String, dynamic> sem) async {
    final existing = sem['endDate'] != null ? DateTime.tryParse(sem['endDate'] as String) : null;
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now().add(const Duration(days: 120)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
      helpText: 'SEMESTER END DATE',
    );
    if (!mounted) return;

    // Allow clearing — if they picked the same date or cancelled show a clear option
    final endDateStr = picked != null
        ? '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}'
        : null;

    if (picked == null && existing == null) return; // nothing to do
    if (picked == null) {
      // Ask if they want to clear
      final clear = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clear End Date?'),
          content: const Text('Remove the end date from this semester?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (clear != true || !mounted) return;
    }

    await StorageService.updateSemesterEndDate(sem['id'] as String, endDateStr);
    if (sem['id'] == StorageService.currentSemesterId) {
      StorageService.currentSemesterEndDate = picked;
    }
    await _load();
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
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateSheet,
          backgroundColor: const Color(0xFF7B61FF),
          child: const Icon(Icons.add, color: Colors.white),
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
        final endDateStr = sem['endDate'] as String?;
        final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
        final isPast = endDate != null && endDate.isBefore(DateTime.now());

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
          subtitle: endDate != null
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.event_rounded, size: 12,
                      color: isPast ? Colors.red.shade400 : Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Ends ${_fmtDate(endDate)}${isPast ? ' · Ended' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPast ? Colors.red.shade400 : Colors.grey.shade500,
                    ),
                  ),
                ])
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.calendar_month_rounded,
                    color: endDate != null ? const Color(0xFF7B61FF) : Colors.grey.shade400,
                    size: 20),
                tooltip: 'Set end date',
                onPressed: () => _showEditEndDate(sem),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
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
