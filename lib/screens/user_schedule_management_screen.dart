import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserScheduleManagementScreen extends StatefulWidget {
  final String userId;
  final String username;
  const UserScheduleManagementScreen({super.key, required this.userId, required this.username});

  @override
  State<UserScheduleManagementScreen> createState() => _UserScheduleManagementScreenState();
}

class _UserScheduleManagementScreenState extends State<UserScheduleManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  List<String> _selectedDays = [];
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  bool _isEditing = false;
  String? _editingScheduleId;
  String _scheduleName = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedules for ${widget.username}'),
      ),
      body: Column(
        children: [
          if (_isEditing) _buildAddScheduleCard(),
          Expanded(
            child: _buildSchedulesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _isEditing = !_isEditing;
            if (!_isEditing) {
              _resetForm();
            }
          });
        },
        icon: Icon(_isEditing ? Icons.close : Icons.add),
        label: Text(_isEditing ? 'Cancel' : 'Add Schedule'),
        backgroundColor: _isEditing ? Colors.red : Colors.blue,
      ),
    );
  }

  Widget _buildAddScheduleCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editingScheduleId == null ? 'Create Access Schedule' : 'Edit Access Schedule',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Schedule Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                onChanged: (value) => _scheduleName = value,
                initialValue: _scheduleName,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Days',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildDaySelector(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeField(
                      'Access Start Time',
                      _startTime,
                      (time) => setState(() => _startTime = time),
                      Icons.access_time,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeField(
                      'Access End Time',
                      _endTime,
                      (time) => setState(() => _endTime = time),
                      Icons.access_time_filled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _saveSchedule,
                    icon: Icon(_editingScheduleId == null ? Icons.add : Icons.save),
                    label: Text(_editingScheduleId == null ? 'Create' : 'Update'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _weekDays.map((day) {
        final isSelected = _selectedDays.contains(day);
        return FilterChip(
          label: Text(day),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedDays.add(day);
              } else {
                _selectedDays.remove(day);
              }
            });
          },
          selectedColor: Colors.blue.withOpacity(0.2),
          checkmarkColor: Colors.blue,
        );
      }).toList(),
    );
  }

  Widget _buildTimeField(
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onChanged,
    IconData icon,
  ) {
    return InkWell(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                timePickerTheme: TimePickerThemeData(
                  backgroundColor: Colors.white,
                  hourMinuteTextColor: Colors.blue,
                  dialHandColor: Colors.blue,
                  dialBackgroundColor: Colors.blue.withOpacity(0.1),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        child: Text(time.format(context)),
      ),
    );
  }

  Widget _buildSchedulesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('User-schedule')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No access schedules yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap the + button to create one',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final schedule = snapshot.data!.docs[index];
            final data = schedule.data() as Map<String, dynamic>;
            final isActive = data['isActive'] ?? true;
            final isFaded = !isActive;
            return Opacity(
              opacity: isFaded ? 0.5 : 1.0,
              child: Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['name'] ?? 'Unnamed Schedule',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Switch(
                        value: isActive,
                        onChanged: (value) => _toggleSchedule(schedule.id, value),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isActive)
                        const Text('Inactive', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text(data['days'].join(', ')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatTimeString(data['startTime'])} - ${_formatTimeString(data['endTime'])}',
                          ),
                        ],
                      ),
                      if (data['lastToggledBy'] != null && data['lastToggledAt'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Last toggled by: ${data['lastToggledBy']} at ${_formatTimestamp(data['lastToggledAt'])}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      // No delete option
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editSchedule(schedule);
                      }
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleSchedule(String scheduleId, bool value) async {
    try {
      final adminUser = await FirebaseFirestore.instance.collection('users').doc(FirebaseFirestore.instance.app.options.projectId).get();
      final toggledBy = adminUser.data()?['username'] ?? adminUser.data()?['email'] ?? 'admin';
      await FirebaseFirestore.instance
          .collection('User-schedule')
          .doc(scheduleId)
          .update({
            'isActive': value,
            'lastToggledBy': toggledBy,
            'lastToggledAt': FieldValue.serverTimestamp(),
          });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Schedule activated.' : 'Schedule deactivated. User will not be able to log in during this time until reactivated.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating schedule: $e')),
      );
    }
  }

  void _showDeleteConfirmation(String scheduleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSchedule(scheduleId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _saveSchedule() async {
    if (!_formKey.currentState!.validate() || _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final scheduleData = {
      'userId': widget.userId,
      'name': _scheduleName,
      'days': _selectedDays,
      'startTime': '${_startTime.hour}:${_startTime.minute}',
      'endTime': '${_endTime.hour}:${_endTime.minute}',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_editingScheduleId != null) {
        await FirebaseFirestore.instance
            .collection('User-schedule')
            .doc(_editingScheduleId)
            .update(scheduleData);
      } else {
        await FirebaseFirestore.instance
            .collection('User-schedule')
            .add(scheduleData);
      }

      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _editSchedule(DocumentSnapshot schedule) {
    final data = schedule.data() as Map<String, dynamic>;
    setState(() {
      _isEditing = true;
      _editingScheduleId = schedule.id;
      _scheduleName = data['name'] ?? '';
      _selectedDays = List<String>.from(data['days']);
      final startTimeParts = data['startTime'].split(':');
      final endTimeParts = data['endTime'].split(':');
      _startTime = TimeOfDay(
        hour: int.parse(startTimeParts[0]),
        minute: int.parse(startTimeParts[1]),
      );
      _endTime = TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      );
    });
  }

  void _deleteSchedule(String scheduleId) async {
    try {
      await FirebaseFirestore.instance
          .collection('User-schedule')
          .doc(scheduleId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting schedule: $e')),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _isEditing = false;
      _editingScheduleId = null;
      _scheduleName = '';
      _selectedDays = [];
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
    });
  }

  String _formatTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final time = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    return time.format(context);
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return timestamp.toString();
  }
} 