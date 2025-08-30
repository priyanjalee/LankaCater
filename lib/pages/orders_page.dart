import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';
import 'caterer_home_page.dart';
import 'event_page.dart';
import 'caterer_profile_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 1;

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('bookings')
          .where('catererId', isEqualTo: user.uid)
          .orderBy('eventDate', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }

  Future<void> _updateOrderStatus(String orderId) async {
    await _firestore
        .collection('bookings')
        .doc(orderId)
        .update({'status': 'Completed'});
  }

  Future<void> _deleteOrder(String orderId) async {
    await _firestore.collection('bookings').doc(orderId).delete();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CatererHomePage()),
        );
        break;
      case 1:
        // Already on Orders page
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EventsPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CatererProfilePage()),
        );
        break;
    }
  }

  Widget _buildOrderCard(DocumentSnapshot<Map<String, dynamic>> order) {
    final data = order.data()!;
    final orderId = order.id;
    final customerName = data['customerName'] ?? 'Customer';
    final status = data['status'] ?? 'Pending';
    final paymentStatus = data['paymentStatus'] ?? 'Pending';
    final eventType = data['eventType'] ?? 'Event';
    final pax = data['pax']?.toString() ?? '-';

    DateTime orderDate;
    final rawDate = data['eventDate'];
    if (rawDate is Timestamp) {
      orderDate = rawDate.toDate();
    } else if (rawDate is String) {
      orderDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      orderDate = DateTime.now();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      shadowColor: Colors.grey.shade300,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text("Order ID: $orderId",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Chip(
                  label: Text(status,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  backgroundColor: status == "Completed"
                      ? Colors.green
                      : Colors.orange,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                ),
              ],
            ),
            const Divider(height: 25, thickness: 1),

            // Details Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Labels
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Customer:", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text("Event:", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text("Guests:", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text("Payment:", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text("Date:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                // Values
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(customerName, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 10),
                    Text(eventType, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 10),
                    Text(pax, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 10),
                    Text(paymentStatus, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 10),
                    Text("${orderDate.toLocal()}".split(' ')[0],
                        style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status != "Completed")
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateOrderStatus(orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kMaincolor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        "Mark Completed",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                if (status != "Completed") const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteOrder(orderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "Delete",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyOrdersWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text(
            "No bookings yet",
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          const Text(
            "Waiting for new bookings from customers",
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CatererHomePage()),
            );
          },
        ),
        title: const Text(
          "Orders",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _ordersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                  child: Text("Error fetching bookings: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _emptyOrdersWidget();
            } else {
              final orders = snapshot.data!.docs;
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) =>
                    _buildOrderCard(orders[index]),
              );
            }
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: kMaincolor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag), label: "Orders"),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
