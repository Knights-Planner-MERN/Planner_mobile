import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/agenda_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String username;
  final String firstName;

  const DashboardScreen({
    Key? key,
    required this.username,
    required this.firstName,
  }) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _currentView = 'Daily';
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<dynamic> _allAppointments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final data = await AgendaService.displayAppointments(widget.username);
      if (!mounted) return;
      setState(() {
        _allAppointments = data['appointments'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error loading schedule: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Returns events for a specific day to populate TableCalendar dot markers
  List<dynamic> _getEventsForDay(DateTime day) {
    return _allAppointments.where((appt) {
      if (appt['starttime'] == null) return false;
      try {
        DateTime eventDate = DateTime.parse(appt['starttime']);
        return eventDate.year == day.year &&
            eventDate.month == day.month &&
            eventDate.day == day.day;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  // Dynamically filters and sorts events chronologically
  List<dynamic> _getFilteredEvents() {
    final filtered = _allAppointments.where((appt) {
      if (appt['starttime'] == null) return false;

      // Search bar filter
      final title = (appt['apptname'] ?? '').toString().toLowerCase();
      if (_searchQuery.isNotEmpty && !title.contains(_searchQuery.toLowerCase())) {
        return false;
      }

      try {
        // Parse raw server timestamp without .toLocal() to avoid UTC-5 shift
        DateTime eventDate = DateTime.parse(appt['starttime']);
        DateTime startOfSelected = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

        if (_currentView == 'Daily') {
          return eventDate.year == _selectedDay.year &&
              eventDate.month == _selectedDay.month &&
              eventDate.day == _selectedDay.day;
        } else if (_currentView == 'Weekly') {
          DateTime weekEnd = startOfSelected.add(const Duration(days: 7));
          return !eventDate.isBefore(startOfSelected) && eventDate.isBefore(weekEnd);
        } else if (_currentView == 'Monthly') {
          return eventDate.year == _selectedDay.year &&
              eventDate.month == _selectedDay.month;
        }
        return false;
      } catch (e) {
        return false;
      }
    }).toList();

    // Sort chronologically by starttime
    filtered.sort((a, b) {
      try {
        return DateTime.parse(a['starttime']).compareTo(DateTime.parse(b['starttime']));
      } catch (_) {
        return 0;
      }
    });

    return filtered;
  }

  String _formatEventTimeRange(String? startIso, String? endIso) {
    if (startIso == null || endIso == null) return 'Time TBA';
    try {
      DateTime start = DateTime.parse(startIso);
      DateTime end = DateTime.parse(endIso);
      String timeRange = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';

      if (_currentView != 'Daily') {
        String dateStr = DateFormat('EEE, MMM d').format(start);
        return '$dateStr  •  $timeRange';
      }
      return timeRange;
    } catch (e) {
      return 'Invalid Time';
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  void _showAddDialog() {
    final TextEditingController nameController = TextEditingController();
    DateTime dialogDate = _selectedDay;
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;
    String? dialogError;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String formattedDate = DateFormat('MM-dd-yyyy').format(dialogDate);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('New Appointment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Event Name',
                        prefixIcon: Icon(Icons.event_note),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Interactive Date Picker
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: const Icon(Icons.calendar_today, color: Colors.blue),
                      title: Text('Date: $formattedDate'),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dialogDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => dialogDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Start Time Picker
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: const Icon(Icons.access_time, color: Colors.blue),
                      title: Text(
                        selectedStartTime == null
                            ? 'Select Start Time'
                            : 'Start: ${_formatTimeOfDay(selectedStartTime!)}',
                      ),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedStartTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setDialogState(() {
                            selectedStartTime = time;
                            dialogError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // End Time Picker
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: const Icon(Icons.access_time_filled, color: Colors.blue),
                      title: Text(
                        selectedEndTime == null
                            ? 'Select End Time'
                            : 'End: ${_formatTimeOfDay(selectedEndTime!)}',
                      ),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedEndTime ?? selectedStartTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setDialogState(() {
                            selectedEndTime = time;
                            dialogError = null;
                          });
                        }
                      },
                    ),

                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty ||
                              selectedStartTime == null ||
                              selectedEndTime == null) {
                            setDialogState(() {
                              dialogError = 'Please enter a name, start time, and end time.';
                            });
                            return;
                          }

                          final startMinutes = selectedStartTime!.hour * 60 + selectedStartTime!.minute;
                          final endMinutes = selectedEndTime!.hour * 60 + selectedEndTime!.minute;
                          if (endMinutes <= startMinutes) {
                            setDialogState(() {
                              dialogError = 'End time must be after start time.';
                            });
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            await AgendaService.createAppointment(
                              widget.username,
                              nameController.text.trim(),
                              formattedDate,
                              _formatTimeOfDay(selectedStartTime!),
                              _formatTimeOfDay(selectedEndTime!),
                            );
                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            setState(() {
                              _selectedDay = dialogDate;
                              _focusedDay = dialogDate;
                            });
                            _showSnackBar('Added "${nameController.text.trim()}"');
                            _fetchAppointments();
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              dialogError = 'Failed to save event: $e';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteAppointment(String appointmentId, String title) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: Text('Remove "$title" from your schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AgendaService.deleteAppointment(widget.username, appointmentId);
        _showSnackBar('Deleted "$title"');
        _fetchAppointments();
      } catch (e) {
        _showSnackBar('Could not delete event: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> displayedEvents = _getFilteredEvents();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          "${widget.firstName}'s Planner",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedDay = DateTime.now();
                _focusedDay = DateTime.now();
              });
            },
            icon: const Icon(Icons.today, size: 18),
            label: const Text('Today'),
          ),
          IconButton(
            tooltip: 'Log Out',
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. View Switcher
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Daily', label: Text('Daily'), icon: Icon(Icons.view_day)),
                ButtonSegment(value: 'Weekly', label: Text('Weekly'), icon: Icon(Icons.view_week)),
                ButtonSegment(value: 'Monthly', label: Text('Monthly'), icon: Icon(Icons.calendar_month)),
              ],
              selected: {_currentView},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _currentView = newSelection.first;
                  _calendarFormat =
                      _currentView == 'Monthly' ? CalendarFormat.month : CalendarFormat.week;
                });
              },
            ),
          ),

          // 2. Dynamic Calendar / Day Scroller
          Container(
            color: Colors.white,
            child: _currentView == 'Daily'
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 30),
                          onPressed: () {
                            setState(() {
                              _selectedDay = _selectedDay.subtract(const Duration(days: 1));
                              _focusedDay = _selectedDay;
                            });
                          },
                        ),
                        Column(
                          children: [
                            Text(
                              DateFormat('EEEE').format(_selectedDay).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              DateFormat('MMMM d, yyyy').format(_selectedDay),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 30),
                          onPressed: () {
                            setState(() {
                              _selectedDay = _selectedDay.add(const Duration(days: 1));
                              _focusedDay = _selectedDay;
                            });
                          },
                        ),
                      ],
                    ),
                  )
                : TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    eventLoader: _getEventsForDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() => _calendarFormat = format);
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),

          // 3. Search Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search events in ${_currentView.toLowerCase()} view...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          // 4. Event List with Loading State & Pull-to-Refresh
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchAppointments,
                    child: displayedEvents.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              const Icon(Icons.event_available, size: 56, color: Colors.grey),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  'No events scheduled for this ${_currentView.toLowerCase()} period',
                                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: displayedEvents.length,
                            itemBuilder: (context, index) {
                              final appt = displayedEvents[index];
                              final String title = appt['apptname'] ?? 'Untitled Event';

                              return Card(
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  leading: Container(
                                    width: 4,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _formatEventTimeRange(appt['starttime'], appt['endtime']),
                                      style: const TextStyle(
                                        color: Colors.blueGrey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () =>
                                        _confirmDeleteAppointment(appt['_id'], title),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Event', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}