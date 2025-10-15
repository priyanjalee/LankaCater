import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/colors.dart';
import 'customer_order_page.dart';
import 'chat_page.dart';

class CatererDetailsPage extends StatefulWidget {
  final String catererId;
  final String customerId;
  final Map<String, dynamic> initialData;

  const CatererDetailsPage({
    super.key,
    required this.catererId,
    required this.customerId,
    required this.initialData,
  });

  @override
  State<CatererDetailsPage> createState() => _CatererDetailsPageState();
}

class _CatererDetailsPageState extends State<CatererDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _isAppBarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(() {
      final isCollapsed = _scrollController.offset > 200;
      if (isCollapsed != _isAppBarCollapsed) {
        setState(() {
          _isAppBarCollapsed = isCollapsed;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black87,
                child: InteractiveViewer(
                  child: Center(
                    child: Hero(
                      tag: imageUrl,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _callNumber(String number) async {
    if (number.isEmpty) return;
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint('Could not launch $number');
    }
  }

  // Combined method to fetch all gallery images
  Future<List<String>> _fetchAllGalleryImages() async {
    try {
      Set<String> galleryImages = <String>{};

      // Fetch from gallery subcollection (used by Manage Gallery page) - Primary source
      final gallerySnapshot = await FirebaseFirestore.instance
          .collection("caterers")
          .doc(widget.catererId)
          .collection("gallery")
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in gallerySnapshot.docs) {
        final data = doc.data();
        final imageUrl = data['imageUrl']?.toString();
        final isActive = data['isActive'] ?? true;
        
        if (imageUrl != null && imageUrl.isNotEmpty && isActive) {
          galleryImages.add(imageUrl);
          debugPrint('Added gallery subcollection image: $imageUrl');
        }
      }

      // Fetch from gallery field in caterer's document (fallback/additional source)
      final catererDoc = await FirebaseFirestore.instance
          .collection("caterers")
          .doc(widget.catererId)
          .get();

      if (catererDoc.exists) {
        final data = catererDoc.data();
        final formGallery = data?['gallery'];
        
        if (formGallery is List) {
          for (var item in formGallery) {
            final imageUrl = item?.toString();
            if (imageUrl != null && imageUrl.isNotEmpty) {
              galleryImages.add(imageUrl);
              debugPrint('Added form gallery image: $imageUrl');
            }
          }
        }
      }

      final resultList = galleryImages.toList();
      debugPrint('Total gallery images fetched: ${resultList.length}');
      
      return resultList;
    } catch (e) {
      debugPrint('Error fetching gallery images: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchReviewsAndRatings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to view reviews.')),
          );
        });
        return {
          'feedback': <Map<String, dynamic>>[],
          'averageRating': 0.0,
          'totalCount': 0,
          'ratingCount': 0,
        };
      }

      // Fetch bookings for this caterer
      QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('catererId', isEqualTo: widget.catererId)
          .get();

      final bookingIds = bookingsSnapshot.docs.map((doc) => doc.id).toList();

      if (bookingIds.isEmpty) {
        return {
          'feedback': <Map<String, dynamic>>[],
          'averageRating': 0.0,
          'totalCount': 0,
          'ratingCount': 0,
        };
      }

      List<Map<String, dynamic>> fetchedFeedback = [];

      // Handle Firestore whereIn limit (max 10 items)
      const int chunkSize = 10;
      for (var i = 0; i < bookingIds.length; i += chunkSize) {
        final chunk = bookingIds.sublist(
          i,
          i + chunkSize > bookingIds.length ? bookingIds.length : i + chunkSize,
        );

        final reviewsSnapshot = await FirebaseFirestore.instance
            .collection('reviews')
            .where('bookingId', whereIn: chunk)
            .orderBy('timestamp', descending: true)
            .get();

        for (var reviewDoc in reviewsSnapshot.docs) {
          final reviewData = reviewDoc.data();
          reviewData['id'] = reviewDoc.id;
          reviewData['timestamp'] = reviewData['timestamp'] ?? Timestamp.now();

          // Fetch customer name - IMPROVED VERSION
          final bookingId = reviewData['bookingId'];
          String customerName = 'Anonymous';
          
          try {
            debugPrint('Fetching booking for ID: $bookingId');
            
            final bookingDoc = await FirebaseFirestore.instance
                .collection('bookings')
                .doc(bookingId)
                .get();

            if (bookingDoc.exists) {
              final bookingData = bookingDoc.data() as Map<String, dynamic>;
              final customerId = bookingData['customerId'];
              
              debugPrint('Found customerId: $customerId');

              if (customerId != null && customerId.toString().isNotEmpty) {
                try {
                  final customerDoc = await FirebaseFirestore.instance
                      .collection('customers')
                      .doc(customerId.toString())
                      .get();

                  if (customerDoc.exists) {
                    final customerData = customerDoc.data() as Map<String, dynamic>;
                    final fetchedName = customerData['name']?.toString().trim();
                    
                    debugPrint('Fetched customer name: $fetchedName');
                    
                    if (fetchedName != null && fetchedName.isNotEmpty) {
                      customerName = fetchedName;
                    } else {
                      // Try alternative name fields
                      final firstName = customerData['firstName']?.toString().trim();
                      final lastName = customerData['lastName']?.toString().trim();
                      
                      if (firstName != null && firstName.isNotEmpty) {
                        customerName = lastName != null && lastName.isNotEmpty 
                            ? '$firstName $lastName' 
                            : firstName;
                      } else {
                        debugPrint('No name fields found in customer document');
                      }
                    }
                  } else {
                    debugPrint('Customer document does not exist for ID: $customerId');
                  }
                } catch (customerError) {
                  debugPrint('Error fetching customer document: $customerError');
                }
              } else {
                debugPrint('CustomerId is null or empty in booking document');
              }
            } else {
              debugPrint('Booking document does not exist for ID: $bookingId');
            }
          } catch (bookingError) {
            debugPrint('Error fetching booking document: $bookingError');
          }

          reviewData['customerName'] = customerName;
          debugPrint('Final customer name set to: $customerName');
          fetchedFeedback.add(reviewData);
        }
      }

      // Sort by timestamp
      fetchedFeedback.sort((a, b) {
        final t1 = a['timestamp'] as Timestamp;
        final t2 = b['timestamp'] as Timestamp;
        return t2.compareTo(t1);
      });

      // Calculate average rating
      double totalRating = 0;
      int ratingCount = 0;
      for (var feedback in fetchedFeedback) {
        final rating = feedback['rating'] as num? ?? 0;
        if (rating > 0) {
          totalRating += rating.toDouble();
          ratingCount++;
        }
      }
      double averageRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

      return {
        'feedback': fetchedFeedback,
        'averageRating': averageRating,
        'totalCount': fetchedFeedback.length,
        'ratingCount': ratingCount,
      };
    } catch (e) {
      debugPrint('Error fetching reviews and ratings: $e');
      if (e.toString().contains('permission-denied')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to view reviews.')),
          );
        });
      }
      return {
        'feedback': <Map<String, dynamic>>[],
        'averageRating': 0.0,
        'totalCount': 0,
        'ratingCount': 0,
      };
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return "Today";
    } else if (difference == 1) {
      return "Yesterday";
    } else if (difference < 7) {
      return "$difference days ago";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  Widget _buildModernInfoTile(IconData icon, String title, String value, {VoidCallback? action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kMaincolor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kMaincolor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : 'N/A',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Container(
              decoration: BoxDecoration(
                color: kMaincolor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: action,
                icon: const Icon(Icons.call, color: Colors.white, size: 18),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index < rating) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              "$stars",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.star, color: Colors.amber, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: kMaincolor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              "$count",
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = review['comment']?.toString() ?? '';
    final timestamp = review['timestamp'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();
    final customerName = review['customerName']?.toString() ?? 'Anonymous';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kMaincolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    customerName.isNotEmpty ? customerName[0].toUpperCase() : 'A',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kMaincolor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStarRating(rating, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _fetchReviewsAndRatings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {
            'feedback': <Map<String, dynamic>>[],
            'averageRating': 0.0,
            'totalCount': 0,
            'ratingCount': 0,
          };

          final feedback = data['feedback'] as List<Map<String, dynamic>>;
          final averageRating = data['averageRating'] as double;
          final totalCount = data['totalCount'] as int;
          final ratingCount = data['ratingCount'] as int;

          // Calculate rating distribution
          Map<int, int> ratingCountMap = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
          for (var review in feedback) {
            final rating = (review['rating'] as num? ?? 0).round();
            if (rating >= 1 && rating <= 5) {
              ratingCountMap[rating] = (ratingCountMap[rating] ?? 0) + 1;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star, color: kMaincolor),
                  const SizedBox(width: 8),
                  Text(
                    "Reviews & Ratings",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kMaincolor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (feedback.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.star_border, size: 36, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          "No reviews yet",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              _buildStarRating(averageRating),
                              const SizedBox(height: 4),
                              Text(
                                '$ratingCount reviews',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          for (int star = 5; star >= 1; star--)
                            _buildRatingBar(star, ratingCountMap[star] ?? 0, totalCount),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Recent Reviews",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kMaincolor,
                      ),
                    ),
                    if (feedback.length > 5)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AllReviewsPage(reviews: feedback),
                            ),
                          );
                        },
                        child: Text(
                          "View All",
                          style: TextStyle(color: kMaincolor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: feedback.length > 5 ? 5 : feedback.length,
                  itemBuilder: (context, index) {
                    return _buildReviewCard(feedback[index]);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // Fixed gallery section using FutureBuilder like reviews
  Widget _buildGallerySection() {
    return FutureBuilder<List<String>>(
      future: _fetchAllGalleryImages(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final galleryImages = snapshot.data ?? [];

        if (galleryImages.isEmpty) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 36, color: Colors.grey),
                  SizedBox(height: 8),
                  Text("No gallery images available", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Main gallery carousel
            SizedBox(
              height: 200,
              child: PageView.builder(
                itemCount: galleryImages.length,
                controller: PageController(viewportFraction: 0.9),
                itemBuilder: (context, index) {
                  final imageUrl = galleryImages[index];
                  return GestureDetector(
                    onTap: () => _showFullScreenImage(context, imageUrl),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Hero(
                          tag: imageUrl,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Thumbnail grid for additional images
            if (galleryImages.length > 1) ...[
              Text(
                "View More (${galleryImages.length} images)",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kMaincolor,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: galleryImages.length > 6 ? 6 : galleryImages.length,
                  itemBuilder: (context, index) {
                    final imageUrl = galleryImages[index];
                    return GestureDetector(
                      onTap: () => _showFullScreenImage(context, imageUrl),
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Image.network(
                                imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                  ),
                                ),
                              ),
                              if (index == 5 && galleryImages.length > 6)
                                Container(
                                  color: Colors.black54,
                                  child: Center(
                                    child: Text(
                                      '+${galleryImages.length - 5}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catererRef =
        FirebaseFirestore.instance.collection("caterers").doc(widget.catererId);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    final chatId = (currentUserId.hashCode <= widget.catererId.hashCode)
        ? "${currentUserId}_${widget.catererId}"
        : "${widget.catererId}_$currentUserId";

    final businessName = widget.initialData['businessName']?.toString() ?? '';
    final distance = widget.initialData['distance'] as double?;

    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: catererRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Scaffold(
              body: Center(child: Text("Caterer not found.")),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Scaffold(
              body: Center(child: Text("Caterer data is empty.")),
            );
          }

          final firestoreBusinessName =
              data['businessName']?.toString() ?? 'Unnamed Caterer';
          final displayBusinessName = businessName.isNotEmpty ? businessName : firestoreBusinessName;
          final contact = data['contact']?.toString() ?? '';
          final email = data['email']?.toString() ?? '';
          final serviceArea = data['serviceArea']?.toString() ?? '';
          final eventTypes =
              ((data['cateredEventTypes'] as List<dynamic>?)?.join(', ')) ?? '';
          final startingPrice = data['startingPrice']?.toString() ?? 'N/A';
          final logoUrl = data['logoUrl']?.toString() ?? '';
          final description = data['description']?.toString() ?? 'No description available.';

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: kMaincolor,
                iconTheme: const IconThemeData(color: Colors.white),
                title: AnimatedOpacity(
                  opacity: _isAppBarCollapsed ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    displayBusinessName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                actions: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
                    builder: (context, snapshot) {
                      bool hasUnread = false;

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                        final lastRead = data["lastRead_$currentUserId"];
                        final lastTimestamp = data["lastTimestamp"];

                        if (lastTimestamp != null &&
                            (lastRead == null || (lastRead as Timestamp).compareTo(lastTimestamp) < 0)) {
                          hasUnread = true;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.chat_bubble_outline),
                                onPressed: () async {
                                  try {
                                    final doc = await catererRef.get();
                                    final data = doc.data();

                                    if (data == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Caterer data not found.')),
                                      );
                                      return;
                                    }

                                    final otherUserName =
                                        data['businessName']?.toString() ?? (businessName.isNotEmpty ? businessName : 'Caterer');
                                    final otherUserImage = data['logoUrl']?.toString() ?? '';

                                    if (currentUserId.isEmpty || widget.catererId.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Invalid user IDs.')),
                                      );
                                      return;
                                    }

                                    final chatRef =
                                        FirebaseFirestore.instance.collection('chats').doc(chatId);

                                    await chatRef.set({
                                      'participants': [currentUserId, widget.catererId],
                                      'lastMessage': '',
                                      'lastTimestamp': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          chatId: chatId,
                                          otherUserName: otherUserName,
                                          otherUserId: widget.catererId,
                                          otherUserImage: otherUserImage,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    debugPrint('Error opening chat: $e');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to open chat.')),
                                    );
                                  }
                                },
                              ),
                            ),
                            if (hasUnread)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  height: 12,
                                  width: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          kMaincolor,
                          kMaincolor.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (logoUrl.isNotEmpty)
                          Positioned.fill(
                            child: Image.network(
                              logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayBusinessName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (distance != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on, color: Colors.white, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${distance.toStringAsFixed(1)} km",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Starting from Rs. $startingPrice / person",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: kMaincolor,
                    labelColor: kMaincolor,
                    unselectedLabelColor: Colors.grey,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: "Overview"),
                      Tab(text: "Menu & Gallery"),
                      Tab(text: "Reviews"),
                    ],
                  ),
                ),
                pinned: true,
              ),

              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(data, contact, email, serviceArea, eventTypes, description),
                    _buildMenuGalleryTab(catererRef),
                    _buildReviewsTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.restaurant, color: Colors.white),
            label: const Text(
              "Book Now",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kMaincolor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              shadowColor: kMaincolor.withOpacity(0.3),
            ),
            onPressed: () async {
              try {
                final doc = await FirebaseFirestore.instance
                    .collection("caterers")
                    .doc(widget.catererId)
                    .get();
                final data = doc.data();
                if (data == null) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerOrderPage(
                      catererId: widget.catererId,
                      catererName: data['businessName']?.toString() ?? businessName,
                    ),
                  ),
                );
              } catch (e) {
                debugPrint('Error booking: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to book order.')),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> data, String contact, String email,
      String serviceArea, String eventTypes, String description) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              border: Border.all(color: kMaincolor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: kMaincolor),
                    const SizedBox(width: 8),
                    Text(
                      "About Us",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kMaincolor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildModernInfoTile(
            Icons.phone,
            "Contact",
            contact,
            action: contact.isNotEmpty ? () => _callNumber(contact) : null,
          ),
          _buildModernInfoTile(Icons.email, "Email", email),
          _buildModernInfoTile(Icons.location_on, "Service Area", serviceArea),
          _buildModernInfoTile(Icons.event, "Event Types", eventTypes),
        ],
      ),
    );
  }

  Widget _buildMenuGalleryTab(DocumentReference catererRef) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library, color: kMaincolor),
              const SizedBox(width: 8),
              Text(
                "Gallery",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kMaincolor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGallerySection(),
          const SizedBox(height: 30),
          Row(
            children: [
              Icon(Icons.restaurant_menu, color: kMaincolor),
              const SizedBox(width: 8),
              Text(
                "Menus & Packages",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kMaincolor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: catererRef.collection("menus").snapshots(),
            builder: (context, menuSnapshot) {
              if (menuSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!menuSnapshot.hasData || menuSnapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.restaurant_menu_outlined, size: 36, color: Colors.grey),
                        SizedBox(height: 8),
                        Text("No menus available", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }

              final menus = menuSnapshot.data!.docs;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: menus.length,
                itemBuilder: (context, index) {
                  final menu = menus[index].data() as Map<String, dynamic>? ?? {};
                  final menuName = menu['name']?.toString() ?? 'Menu';
                  final menuDesc = menu['description']?.toString() ?? '';
                  final menuPrice = menu['price']?.toString() ?? 'N/A';
                  final menuImage = menu['imageUrl']?.toString() ?? '';

                  return GestureDetector(
                    onTap: menuImage.isNotEmpty ? () => _showFullScreenImage(context, menuImage) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: menuImage.isNotEmpty
                                  ? Image.network(
                                      menuImage,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Center(child: CircularProgressIndicator()),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
                                      ),
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  menuName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  menuDesc,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  menuPrice.isNotEmpty ? 'Rs. $menuPrice' : 'Price not available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: kMaincolor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

class AllReviewsPage extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;

  const AllReviewsPage({super.key, required this.reviews});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return "Today";
    } else if (difference == 1) {
      return "Yesterday";
    } else if (difference < 7) {
      return "$difference days ago";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  Widget _buildStarRating(double rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index < rating) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = review['comment']?.toString() ?? '';
    final timestamp = review['timestamp'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();
    final customerName = review['customerName']?.toString() ?? 'Anonymous';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kMaincolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    customerName.isNotEmpty ? customerName[0].toUpperCase() : 'A',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kMaincolor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStarRating(rating, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Reviews"),
        backgroundColor: kMaincolor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (reviews.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.star_border, size: 36, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        "No reviews yet",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  return _buildReviewCard(reviews[index]);
                },
              ),
          ],
        ),
      ),
    );
  }
}