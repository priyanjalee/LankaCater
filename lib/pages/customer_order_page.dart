// customer_order_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';

class CustomerOrderPage extends StatefulWidget {
  final String catererId;
  final String catererName;

  const CustomerOrderPage({
    super.key,
    required this.catererId,
    required this.catererName,
  });

  @override
  State<CustomerOrderPage> createState() => _CustomerOrderPageState();
}

class _CustomerOrderPageState extends State<CustomerOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _eventDateController = TextEditingController();
  final TextEditingController _eventTypeController = TextEditingController();
  final TextEditingController _paxController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _menuController = TextEditingController(); // Changed from dropdown to text field
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final customerData = {
          'customerId': currentUser.uid,
          'customerName': _nameController.text.trim(),
          'customerEmail': _emailController.text.trim(),
          'customerPhone': _phoneController.text.trim(),
          'customerAddress': _addressController.text.trim(),
          'eventDate': _eventDateController.text.trim(),
          'eventType': _eventTypeController.text.trim(),
          'noOfPax': int.tryParse(_paxController.text.trim()) ?? 0,
          'menu': _menuController.text.trim(), // Changed from _selectedMenu to _menuController.text
          'message': _messageController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'isNew': true, // Flag for new orders
          'isViewed': false, // Flag to track if caterer has viewed the order
        };

        // Save to caterer's orders collection
        await FirebaseFirestore.instance
            .collection('caterers')
            .doc(widget.catererId)
            .collection('orders')
            .add(customerData);

        // Save to bookings collection for customer's bookings page
        await FirebaseFirestore.instance.collection('bookings').add({
          'customerId': currentUser.uid,
          'catererId': widget.catererId,
          'catererName': widget.catererName,
          'catererContact': 'N/A',
          ...customerData,
          'status': 'Pending',
          'paymentStatus': 'Unpaid',
        });

        // Update caterer's notification count
        await _updateNotificationCount();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text("Order sent successfully!", style: TextStyle(fontSize: 16)),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

          _clearForm();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text("Failed to send order: $e")),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _updateNotificationCount() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('caterers')
          .doc(widget.catererId);
      
      await docRef.update({
        'newOrdersCount': FieldValue.increment(1),
        'lastOrderTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // If document doesn't exist, create it
      await FirebaseFirestore.instance
          .collection('caterers')
          .doc(widget.catererId)
          .set({
        'newOrdersCount': 1,
        'lastOrderTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  void _clearForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _eventDateController.clear();
    _eventTypeController.clear();
    _paxController.clear();
    _messageController.clear();
    _menuController.clear(); // Changed from _selectedMenu = null to _menuController.clear()
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: kMaincolor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _eventDateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kMaincolor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Contact ${widget.catererName}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kMaincolor.withOpacity(0.1), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kMaincolor.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.restaurant_menu, size: 48, color: kMaincolor),
                    const SizedBox(height: 12),
                    Text(
                      "Place Your Order",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: kMaincolor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Fill in the details below to send your catering request",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Personal Information Section
              _buildSectionTitle("Personal Information", Icons.person),
              const SizedBox(height: 16),
              _buildTextField(_nameController, "Full Name", Icons.person, "Enter your full name"),
              const SizedBox(height: 16),
              _buildTextField(_emailController, "Email Address", Icons.email, "Enter your email address",
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(_phoneController, "Phone Number", Icons.phone, "Enter your phone number",
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField(_addressController, "Address", Icons.location_on, "Enter your complete address",
                  maxLines: 2),
              const SizedBox(height: 24),

              // Event Information Section
              _buildSectionTitle("Event Details", Icons.event),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 16),
              _buildTextField(_eventTypeController, "Event Type", Icons.celebration, "e.g., Wedding, Birthday, Corporate"),
              const SizedBox(height: 16),
              // Number of Guests field with enhanced styling
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _paxController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Number of guests is required';
                    }
                    final int? guests = int.tryParse(value.trim());
                    if (guests == null || guests <= 0) {
                      return 'Please enter a valid number of guests';
                    }
                    if (guests > 10000) {
                      return 'Number of guests seems too high';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kMaincolor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.people, color: kMaincolor, size: 20),
                    ),
                    labelText: "Number of Guests",
                    hintText: "Enter number of guests (e.g., 50)",
                    helperText: "Please provide approximate number of attendees",
                    labelStyle: TextStyle(color: kMaincolor, fontWeight: FontWeight.w600),
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    helperStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kMaincolor, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuTextField(), // Changed from _buildMenuDropdown() to _buildMenuTextField()
              const SizedBox(height: 24),

              // Additional Information Section
              _buildSectionTitle("Additional Information", Icons.message),
              const SizedBox(height: 16),
              _buildTextField(_messageController, "Special Requirements", Icons.message, 
                  "Any special requirements or dietary restrictions...", maxLines: 4),
              const SizedBox(height: 32),

              // Order Summary Card (optional - shows what user entered)
              if (_paxController.text.isNotEmpty || _menuController.text.isNotEmpty) // Changed condition
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Order Summary",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_paxController.text.isNotEmpty)
                        Text("Guests: ${_paxController.text} people", 
                             style: const TextStyle(fontSize: 14)),
                      if (_menuController.text.isNotEmpty) // Changed from _selectedMenu
                        Text("Menu: ${_menuController.text}", 
                             style: const TextStyle(fontSize: 14)),
                      if (_eventDateController.text.isNotEmpty)
                        Text("Date: ${_eventDateController.text}", 
                             style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),

              // Submit Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kMaincolor, kMaincolor.withOpacity(0.8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kMaincolor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _sendMessage,
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text("Sending...", style: TextStyle(fontSize: 18, color: Colors.white)),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send, color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Text("Send Order Request", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          if (keyboardType == TextInputType.emailAddress) {
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
          }
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kMaincolor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kMaincolor, size: 20),
          ),
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: kMaincolor, fontWeight: FontWeight.w600),
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kMaincolor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _eventDateController,
        readOnly: true,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Event date is required';
          }
          return null;
        },
        onTap: () => _selectDate(context),
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kMaincolor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.calendar_today, color: kMaincolor, size: 20),
          ),
          suffixIcon: Icon(Icons.arrow_drop_down, color: kMaincolor),
          labelText: "Event Date",
          hintText: "Select your event date",
          labelStyle: TextStyle(color: kMaincolor, fontWeight: FontWeight.w600),
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kMaincolor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // NEW METHOD: Text field for menu input instead of dropdown
  Widget _buildMenuTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _menuController,
        maxLines: 2,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Menu selection is required';
          }
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kMaincolor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.restaurant_menu, color: kMaincolor, size: 20),
          ),
          labelText: "Menu Items",
          hintText: "Enter the menu items you're interested in (e.g., Rice & Curry, Biryani, Desserts)",
          helperText: "Please specify the menu items or packages offered by this caterer",
          labelStyle: TextStyle(color: kMaincolor, fontWeight: FontWeight.w600),
          hintStyle: TextStyle(color: Colors.grey[400]),
          helperStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kMaincolor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _eventDateController.dispose();
    _eventTypeController.dispose();
    _paxController.dispose();
    _messageController.dispose();
    _menuController.dispose(); // Added disposal for menu controller
    super.dispose();
  }
}

// Notification Badge Widget - Use this wherever you want to show notification dots
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final String catererId;
  final bool showCount;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.catererId,
    this.showCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('caterers')
          .doc(catererId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return child;
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final newOrdersCount = data?['newOrdersCount'] ?? 0;
        
        if (newOrdersCount == 0) return child;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: EdgeInsets.all(showCount ? 4 : 6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(
                  minWidth: showCount ? 18 : 12,
                  minHeight: showCount ? 18 : 12,
                ),
                child: showCount && newOrdersCount > 0
                    ? Text(
                        newOrdersCount > 99 ? '99+' : '$newOrdersCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}