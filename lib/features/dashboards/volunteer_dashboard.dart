import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stray_resuce_bih/core/theme/app_theme.dart';
import 'package:stray_resuce_bih/core/services/firebase_service.dart';
import 'package:stray_resuce_bih/features/auth/screens/welcome_screen.dart';
import 'package:stray_resuce_bih/features/report/rescue_reports_screen.dart';
import 'package:stray_resuce_bih/features/profile/profile_screen.dart';
import 'package:stray_resuce_bih/features/notifications/notifications_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:stray_resuce_bih/features/feed/add_feed_location_screen.dart';

/// Volunteer Dashboard
class VolunteerDashboard extends ConsumerStatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  ConsumerState<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends ConsumerState<VolunteerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _VolunteerReportsFeed(), // Feed locations (feeding stations)
    RescueReportsScreen(),   // All rescue reports from citizens
    NotificationsScreen(),
    ProfileScreen(),
  ];

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FirebaseService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤝 Volunteer Dashboard'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryOrange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _VolunteerReportsFeed extends StatelessWidget {
  const _VolunteerReportsFeed();

  Future<void> _openMap(BuildContext context, GeoPoint location) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps application')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error opening maps: $e')),
      );
    }
  }

  void _navigateToAddFeedLocation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddFeedLocationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feed_locations')
            .orderBy('addedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
           if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
           if (docs.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.restaurant, size: 100, color: AppTheme.primaryOrange),
                   const SizedBox(height: 24),
                   const Text(
                     'No Feed Locations Yet',
                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 12),
                   const Padding(
                     padding: EdgeInsets.symmetric(horizontal: 32),
                     child: Text(
                       'Add feeding stations where food is available for stray animals',
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey, fontSize: 16),
                     ),
                   ),
                   const SizedBox(height: 32),
                   ElevatedButton.icon(
                     onPressed: () => _navigateToAddFeedLocation(context),
                     icon: const Icon(Icons.add_location),
                     label: const Text('Add Feed Location'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppTheme.primaryOrange,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                   ),
                 ],
               ),
             );
           }

           return ListView.builder(
             padding: const EdgeInsets.all(16),
             itemCount: docs.length,
             itemBuilder: (context, index) {
               final data = docs[index].data() as Map<String, dynamic>;
               final GeoPoint? location = data['location'];
               final String name = data['name'] ?? 'Unnamed Location';
               final String address = data['address'] ?? 'No address';
               final String description = data['description'] ?? '';
               
               return Card(
                 margin: const EdgeInsets.only(bottom: 16),
                 elevation: 4,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                 child: Padding(
                   padding: const EdgeInsets.all(16),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: Colors.green[50],
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: const Icon(Icons.restaurant, color: Colors.green, size: 28),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   name,
                                   style: const TextStyle(
                                     fontWeight: FontWeight.bold,
                                     fontSize: 18,
                                   ),
                                 ),
                                 if (description.isNotEmpty) ...[
                                   const SizedBox(height: 4),
                                   Text(
                                     description,
                                     style: TextStyle(
                                       color: Colors.grey[600],
                                       fontSize: 14,
                                     ),
                                   ),
                                 ],
                               ],
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 12),
                       Row(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Icon(Icons.location_on, size: 18, color: AppTheme.primaryOrange),
                           const SizedBox(width: 8),
                           Expanded(
                             child: Text(
                               address,
                               style: const TextStyle(fontSize: 14, height: 1.4),
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),
                       if (location != null)
                         SizedBox(
                           width: double.infinity,
                           child: ElevatedButton.icon(
                             onPressed: () => _openMap(context, location),
                             icon: const Icon(Icons.directions),
                             label: const Text('Get Directions'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: AppTheme.primaryOrange,
                               foregroundColor: Colors.white,
                               padding: const EdgeInsets.symmetric(vertical: 12),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                             ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddFeedLocation(context),
        icon: const Icon(Icons.add_location),
        label: const Text('Add Feed Location'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
    );
  }
}
