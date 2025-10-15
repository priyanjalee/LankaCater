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

class _OrdersPageState extends State<OrdersPage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 1;
  String _selectedFilter = 'All';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isAnimationInitialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isAnimationInitialized = true;
          _animationController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    final user = _auth.currentUser;
    if (user != null) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('caterers')
          .doc(user.uid)
          .collection('orders')
          .orderBy('timestamp', descending: true);

      if (_selectedFilter != 'All') {
        query = query.where('status', isEqualTo: _selectedFilter);
      }

      return query.snapshots();
    }
    return const Stream.empty();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _newOrdersStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('caterers')
          .doc(user.uid)
          .collection('orders')
          .where('isNew', isEqualTo: true)
          .where('isViewed', isEqualTo: false)
          .snapshots();
    }
    return const Stream.empty();
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus, String customerId) async {
    try {
      await _firestore
          .collection('caterers')
          .doc(_auth.currentUser!.uid)
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'isNew': false,
        'isViewed': true,
      });

      await _firestore
          .collection('bookings')
          .where('customerId', isEqualTo: customerId)
          .where('catererId', isEqualTo: _auth.currentUser!.uid)
          .where('timestamp', isEqualTo: (await _firestore
              .collection('caterers')
              .doc(_auth.currentUser!.uid)
              .collection('orders')
              .doc(orderId)
              .get())
              .data()!['timestamp'])
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'status': newStatus});
        }
      });

      await _firestore.collection('caterers').doc(_auth.currentUser!.uid).update({
        'newOrdersCount': FieldValue.increment(-1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deleteOrder(String orderId, String customerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to delete this order? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('caterers')
            .doc(_auth.currentUser!.uid)
            .collection('orders')
            .doc(orderId)
            .delete();

        await _firestore
            .collection('bookings')
            .where('customerId', isEqualTo: customerId)
            .where('catererId', isEqualTo: _auth.currentUser!.uid)
            .where('timestamp', isEqualTo: (await _firestore
                .collection('caterers')
                .doc(_auth.currentUser!.uid)
                .collection('orders')
                .doc(orderId)
                .get())
                .data()!['timestamp'])
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Order deleted successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting order: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CatererHomePage()),
        );
        break;
      case 1:
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventsPage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CatererProfilePage()),
        );
        break;
    }
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Pending', 'Accepted', 'Rejected'];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedFilter = filter);
              },
              backgroundColor: Colors.white,
              selectedColor: kMaincolor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? kMaincolor : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? kMaincolor : Colors.grey[300]!,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ordersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final orders = snapshot.data!.docs;
        final pendingCount = orders.where((o) => o.data()['status'] == 'Pending').length;
        final acceptedCount = orders.where((o) => o.data()['status'] == 'Accepted').length;
        final totalOrders = orders.length;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildStatCard('Total', totalOrders, Icons.shopping_bag)),
              Expanded(child: _buildStatCard('Pending', pendingCount, Icons.pending)),
              Expanded(child: _buildStatCard('Accepted', acceptedCount, Icons.check_circle)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kMaincolor, size: 24),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kMaincolor,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: kMaincolor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(DocumentSnapshot<Map<String, dynamic>> order, int index) {
    final data = order.data()!;
    final orderId = order.id;
    final customerName = data['customerName'] ?? 'Unknown';
    final status = data['status'] ?? 'Pending';
    final eventType = data['eventType'] ?? 'Not specified';
    final noOfPax = data['noOfPax']?.toString() ?? 'Not specified';
    final eventDate = data['eventDate'] ?? 'Not specified';
    final customerEmail = data['customerEmail'] ?? 'Not specified';
    final customerPhone = data['customerPhone'] ?? 'Not specified';
    final customerAddress = data['customerAddress'] ?? 'Not specified';
    final menu = data['menu'] ?? 'Not specified';
    final message = data['message'] ?? 'No additional information';
    final isNew = data['isNew'] ?? false;
    final isViewed = data['isViewed'] ?? false;
    final customerId = data['customerId'] ?? '';

    if (!_isAnimationInitialized) {
      return _buildOrderCardContent(
        orderId,
        customerName,
        status,
        eventType,
        noOfPax,
        eventDate,
        customerEmail,
        customerPhone,
        customerAddress,
        menu,
        message,
        isNew,
        isViewed,
        customerId,
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
        )),
        child: _buildOrderCardContent(
          orderId,
          customerName,
          status,
          eventType,
          noOfPax,
          eventDate,
          customerEmail,
          customerPhone,
          customerAddress,
          menu,
          message,
          isNew,
          isViewed,
          customerId,
        ),
      ),
    );
  }

  Widget _buildOrderCardContent(
    String orderId,
    String customerName,
    String status,
    String eventType,
    String noOfPax,
    String eventDate,
    String customerEmail,
    String customerPhone,
    String customerAddress,
    String menu,
    String message,
    bool isNew,
    bool isViewed,
    String customerId,
  ) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kMaincolor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #${orderId.substring(0, 8)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customerName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildStatusChip(status),
                    if (isNew && !isViewed) ...[
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          "New",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("Customer Details", Icons.person),
                const SizedBox(height: 8),
                _buildDetailContainer(Icons.person, "Name", customerName, Colors.blue),
                _buildDetailContainer(Icons.email, "Email", customerEmail, Colors.blue),
                _buildDetailContainer(Icons.phone, "Phone", customerPhone, Colors.blue),
                _buildDetailContainer(Icons.location_on, "Address", customerAddress, Colors.blue, maxLines: 2),
                const SizedBox(height: 16),
                _buildSectionTitle("Event Details", Icons.event),
                const SizedBox(height: 8),
                _buildDetailContainer(Icons.event, "Event Type", eventType, Colors.green),
                _buildDetailContainer(Icons.people, "Guests", noOfPax, Colors.green),
                _buildDetailContainer(Icons.calendar_today, "Event Date", eventDate, Colors.green),
                _buildDetailContainer(Icons.restaurant_menu, "Menu", menu, Colors.green, maxLines: 2),
                const SizedBox(height: 16),
                _buildSectionTitle("Additional Information", Icons.message),
                const SizedBox(height: 8),
                _buildDetailContainer(Icons.message, "Message", message, Colors.orange, maxLines: 4),
                const SizedBox(height: 16),
                _buildDetailContainer(Icons.info, "Status", status, Colors.grey),
                const SizedBox(height: 20),
                _buildActionButtons(orderId, status, customerId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kMaincolor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kMaincolor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kMaincolor,
            shadows: [
              Shadow(color: Colors.black12, offset: const Offset(1, 1), blurRadius: 2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (status.toLowerCase()) {
      case 'accepted':
        backgroundColor = Colors.green;
        break;
      case 'rejected':
        backgroundColor = Colors.red;
        break;
      case 'pending':
        backgroundColor = Colors.orange;
        break;
      default:
        backgroundColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailContainer(IconData icon, String label, String value, Color color, {int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String orderId, String status, String customerId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (status.toLowerCase() != 'accepted' && status.toLowerCase() != 'rejected') ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showStatusUpdateDialog(orderId, status, customerId),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Update Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kMaincolor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
            ),
          ),
        ],
        if (status.toLowerCase() != 'accepted' && status.toLowerCase() != 'rejected') const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _deleteOrder(orderId, customerId),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  void _showStatusUpdateDialog(String orderId, String currentStatus, String customerId) {
    final statuses = ['Pending', 'Accepted', 'Rejected'];
    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Order Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select new status for this order:'),
              const SizedBox(height: 16),
              ...statuses.map((status) => RadioListTile<String>(
                title: Text(status),
                value: status,
                groupValue: selectedStatus,
                onChanged: (value) => setDialogState(() => selectedStatus = value!),
                activeColor: kMaincolor,
              )),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateOrderStatus(orderId, selectedStatus, customerId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: kMaincolor),
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyOrdersWidget() {
    return FadeTransition(
      opacity: _isAnimationInitialized ? _fadeAnimation : const AlwaysStoppedAnimation(1.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 100,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "No Orders Found",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                shadows: [
                  Shadow(color: Colors.black12, offset: Offset(1, 1), blurRadius: 2),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _selectedFilter == 'All'
                    ? "You don't have any bookings yet. New orders will appear here when customers make bookings."
                    : "No orders found with '$_selectedFilter' status.",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (_selectedFilter != 'All') ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() => _selectedFilter = 'All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMaincolor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Show All Orders', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view orders")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: kMaincolor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CatererHomePage()),
            );
          },
        ),
        title: const Text(
          "Order Management",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kMaincolor, kMaincolor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: kMaincolor,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildStatsCard(),
                    _buildFilterChips(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _ordersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: kMaincolor),
                          const SizedBox(height: 16),
                          Text(
                            'Loading orders...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          const Text(
                            "Error Loading Orders",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text("${snapshot.error}"),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _emptyOrdersWidget();
                  } else {
                    final orders = snapshot.data!.docs;

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      color: kMaincolor,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: orders.length,
                        itemBuilder: (context, index) => _buildOrderCard(orders[index], index),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _newOrdersStream(),
        builder: (context, newOrdersSnapshot) {
          final hasNewOrders = newOrdersSnapshot.hasData && newOrdersSnapshot.data!.docs.isNotEmpty;

          return Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              selectedItemColor: kMaincolor,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              onTap: _onItemTapped,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: "Home",
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_bag),
                      if (hasNewOrders)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: "Orders",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.event),
                  label: "Events",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Profile",
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}