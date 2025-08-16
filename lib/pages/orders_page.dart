import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 1; // Orders tab selected

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('orders')
          .where('catererId', isEqualTo: user.uid)
          .snapshots();
    }
    return const Stream.empty();
  }

  Future<void> _updateOrderStatus(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({'status': 'Completed'});
  }

  Future<void> _deleteOrder(String orderId) async {
    await _firestore.collection('orders').doc(orderId).delete();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/caterer_home');
        break;
      case 1:
        // Already on orders page
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/events');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/edit-profile');
        break;
    }
  }

  Widget _buildOrderCard(DocumentSnapshot<Map<String, dynamic>> order) {
    final data = order.data()!;
    final orderId = order.id;
    final customerName = data['customerName'] ?? 'Customer';
    final orderItems = List<String>.from(data['items'] ?? []);
    final status = data['status'] ?? 'Pending';
    final orderDate = (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final paymentStatus = data['paymentStatus'] ?? 'Pending';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Order ID: $orderId", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Customer: $customerName"),
            const SizedBox(height: 4),
            Text("Items: ${orderItems.join(', ')}"),
            const SizedBox(height: 4),
            Text(
              "Status: $status",
              style: TextStyle(
                color: status == "Completed" ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text("Payment: $paymentStatus"),
            const SizedBox(height: 4),
            Text("Date: ${orderDate.toLocal()}".split(' ')[0]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status != "Completed")
                  ElevatedButton(
                    onPressed: () => _updateOrderStatus(orderId),
                    style: ElevatedButton.styleFrom(backgroundColor: kMaincolor),
                    child: const Text("Mark Completed"),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _deleteOrder(orderId),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text("Delete"),
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
          Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            "No orders yet",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            "Waiting for new orders from customers",
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
            Navigator.pushReplacementNamed(context, '/caterer_home');
          },
        ),
        title: const Text(
          "Orders",
          style: TextStyle(
            fontFamily: 'Inter',
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
              return Center(child: Text("Error fetching orders: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _emptyOrdersWidget();
            } else {
              final orders = snapshot.data!.docs;
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) => _buildOrderCard(orders[index]),
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
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "Orders"),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
