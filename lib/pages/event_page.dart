import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _currentIndex = 2;
  final user = FirebaseAuth.instance.currentUser;

  String _dateToKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  void _onBottomNavTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/orders');
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/caterer-profile');
        break;
    }
  }

  Future<void> _showAddEventDialog() async {
    if (_selectedDay == null) return;
    String newEvent = '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.event_available, color: kMaincolor, size: 28),
            const SizedBox(width: 12),
            const Text("Add New Event", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Date: ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter event details",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kMaincolor, width: 2),
                ),
                prefixIcon: Icon(Icons.edit, color: kMaincolor),
              ),
              onChanged: (value) => newEvent = value,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMaincolor,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (newEvent.trim().isEmpty) return;
              final dateKey = _dateToKey(_selectedDay!);

              final docRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('events')
                  .doc(dateKey);

              await docRef.set({
                'events': FieldValue.arrayUnion([newEvent])
              }, SetOptions(merge: true));

              Navigator.pop(context);
            },
            child: const Text("Add Event"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(String dateKey, String event) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('events')
        .doc(dateKey);

    await docRef.update({
      'events': FieldValue.arrayRemove([event])
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Events",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: kMaincolor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Calendar Section
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                    color: kMaincolor,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  defaultTextStyle: const TextStyle(
                    color: Color(0xFF2D3748),
                    fontWeight: FontWeight.w500,
                  ),
                  weekendTextStyle: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: kMaincolor,
                    size: 24,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: kMaincolor,
                    size: 24,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .collection('events')
                          .doc(_dateToKey(date))
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }
                        final eventList =
                            List<String>.from(snapshot.data!.get('events'));
                        if (eventList.isNotEmpty) {
                          return Positioned(
                            bottom: 4,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // Events Section Header
          if (_selectedDay != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: kMaincolor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: kMaincolor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Events for ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kMaincolor,
                    ),
                  ),
                ],
              ),
            ),

          // Events List
          Expanded(
            child: _selectedDay == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Select a date",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Choose a date from the calendar to view events",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .collection('events')
                        .doc(_dateToKey(_selectedDay!))
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(kMaincolor),
                          ),
                        );
                      }

                      final events = (snapshot.hasData &&
                              snapshot.data!.exists &&
                              snapshot.data!.get('events') != null)
                          ? List<String>.from(snapshot.data!.get('events'))
                          : [];

                      if (events.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_note_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No events yet",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Tap the + button to add your first event",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(top: 16, bottom: 100),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: events.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final event = events[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border(
                                  left: BorderSide(
                                    color: kMaincolor,
                                    width: 4,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: kMaincolor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.event_outlined,
                                      color: kMaincolor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      event,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2D3748),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _deleteEvent(
                                        _dateToKey(_selectedDay!), event),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedDay != null
          ? FloatingActionButton(
              onPressed: _showAddEventDialog,
              backgroundColor: kMaincolor,
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 28,
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onBottomNavTap,
          selectedItemColor: kMaincolor,
          unselectedItemColor: Colors.grey[400],
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_rounded),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_rounded),
              label: 'Events',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}