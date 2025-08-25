// customer_order_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final TextEditingController _eventDateController = TextEditingController();
  final TextEditingController _eventTypeController = TextEditingController();
  final TextEditingController _paxController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String? _selectedMenu;

  final List<String> _menuOptions = [
    '1st Menu',
    '2nd Menu',
    '3rd Menu',
  ];

  Future<void> _sendMessage() async {
    if (_formKey.currentState!.validate() && _selectedMenu != null) {
      try {
        final customerData = {
          'customerName': _nameController.text.trim(),
          'customerEmail': _emailController.text.trim(),
          'customerPhone': _phoneController.text.trim(),
          'eventDate': _eventDateController.text.trim(),
          'eventType': _eventTypeController.text.trim(),
          'noOfPax': _paxController.text.trim(),
          'menu': _selectedMenu,
          'message': _messageController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        };

        // Save to caterer's orders collection
        await FirebaseFirestore.instance
            .collection('caterers')
            .doc(widget.catererId)
            .collection('orders')
            .add(customerData);

        // Save to bookings collection for customer's bookings page
        await FirebaseFirestore.instance.collection('bookings').add({
          'customerId': 'YOUR_CUSTOMER_ID', // replace with FirebaseAuth.currentUser!.uid
          'catererId': widget.catererId,
          'catererName': widget.catererName,
          'catererContact': 'N/A', // optional, can fetch from caterer profile
          ...customerData,
          'status': 'Pending',
          'paymentStatus': 'Unpaid',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Order sent to the caterer successfully!"),
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          _selectedMenu = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send order: $e"),
          ),
        );
      }
    } else if (_selectedMenu == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a menu"),
        ),
      );
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildTextField(_nameController, "Your Name", Icons.person),
                const SizedBox(height: 12),
                _buildTextField(_emailController, "Email", Icons.email,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildTextField(_phoneController, "Phone Number", Icons.phone,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildTextField(_eventDateController, "Event Date", Icons.date_range),
                const SizedBox(height: 12),
                _buildTextField(_eventTypeController, "Event Type", Icons.event),
                const SizedBox(height: 12),
                _buildTextField(_paxController, "Number of Pax", Icons.people,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),

                // Menu Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedMenu,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.menu_book, color: kMaincolor),
                    labelText: "Select Menu",
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kMaincolor, width: 2),
                    ),
                  ),
                  items: _menuOptions
                      .map((menu) => DropdownMenuItem(
                            value: menu,
                            child: Text(menu),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMenu = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a menu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                _buildTextField(_messageController, "Message", Icons.message,
                    maxLines: 5),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMaincolor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _sendMessage,
                    child: const Text(
                      "Send Message to Caterer",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: kMaincolor),
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kMaincolor, width: 2),
        ),
      ),
    );
  }
}
