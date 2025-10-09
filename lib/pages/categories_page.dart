import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final allCategories = [
      // Use TYPE: for full-vehicle listings and CAT: for parts categories
      {'name': 'Vehicles & Cars', 'icon': Icons.directions_car, 'color': Colors.blue, 'description': 'Complete vehicles and car listings', 'code': 'TYPE:car'},
      {'name': 'Engine Parts', 'icon': Icons.settings, 'color': Colors.orange, 'description': 'Engine components and accessories', 'code': 'CAT:engine'},
      {'name': 'Tires & Wheels', 'icon': Icons.album, 'color': Colors.green, 'description': 'Tires, rims, and wheel accessories', 'code': 'CAT:wheels'},
      {'name': 'Electronics', 'icon': Icons.electrical_services, 'color': Colors.purple, 'description': 'Car electronics and audio systems', 'code': 'CAT:electronics'},
      {'name': 'Body Parts', 'icon': Icons.build, 'color': Colors.red, 'description': 'Exterior body parts', 'code': 'CAT:exterior'},
      {'name': 'Brakes', 'icon': Icons.speed, 'color': Colors.deepOrange, 'description': 'Brake pads, rotors, and systems', 'code': 'CAT:brakes'},
      {'name': 'Suspension', 'icon': Icons.vertical_align_center, 'color': Colors.indigo, 'description': 'Shocks, struts, and suspension parts', 'code': 'CAT:suspension'},
      {'name': 'Interior', 'icon': Icons.airline_seat_recline_normal, 'color': Colors.brown, 'description': 'Seats, dashboards, and interior accessories', 'code': 'CAT:interior'},
      {'name': 'Accessories', 'icon': Icons.star, 'color': Colors.amber, 'description': 'Car accessories and add-ons', 'code': 'CAT:accessories'},
      {'name': 'Wheels', 'icon': Icons.donut_large, 'color': Colors.cyan, 'description': 'Alloy wheels and steel rims', 'code': 'CAT:wheels'},
      {'name': 'Audio', 'icon': Icons.speaker, 'color': Colors.pink, 'description': 'Car audio systems and speakers', 'code': 'CAT:audio'},
      {'name': 'Lighting', 'icon': Icons.lightbulb, 'color': Colors.yellow, 'description': 'Headlights, taillights, and LED accessories', 'code': 'CAT:lighting'},
      {'name': 'Tyres', 'icon': Icons.circle, 'color': Colors.green.shade700, 'description': 'Tyres and related parts', 'code': 'CAT:tyres'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'All Categories',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Browse by Category',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find exactly what you\'re looking for',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: allCategories.length,
                itemBuilder: (context, index) {
                  final category = allCategories[index];
                  return _buildCategoryCard(context, category);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> category) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final String code = category['code'] as String? ?? '';
          // Return a selection code back to the caller (e.g., 'CAT:engine' or 'TYPE:car')
          context.pop<String>(code);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: (category['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  category['icon'] as IconData,
                  color: category['color'] as Color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                category['name'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C2C2C),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                category['description'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
