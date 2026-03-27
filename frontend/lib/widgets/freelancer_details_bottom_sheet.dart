import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class FreelancerDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> freelancer;

  const FreelancerDetailsBottomSheet({
    super.key,
    required this.freelancer,
  });

  @override
  Widget build(BuildContext context) {
    // The main container of the bottom sheet
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 25,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle container
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),

          // Content section
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main content below the avatar breakout
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: Empty space for Avatar on left, Rate Box on right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Placeholder for the avatar space in the layout
                        const SizedBox(width: 80, height: 40),

                        // Rate Box (mt-4 in HTML = 16px top margin)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${freelancer['rate']}',
                                style: const TextStyle(
                                  fontFamily: 'Mona_Sans',
                                  fontSize: 20, // text-xl
                                  fontWeight: FontWeight.w700, // font-bold
                                  color: Color(0xFF0A192F), // text-navy
                                  height: 1.0,
                                ),
                              ),
                              const Text(
                                '/hr',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14, // text-sm
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF64748B), // text-slate
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Header Info (mt-3 in HTML = 12px)
                    const SizedBox(height: 12),
                    Text(
                      freelancer['name']!,
                      style: const TextStyle(
                        fontFamily: 'Mona_Sans',
                        fontSize: 24, // text-2xl
                        fontWeight: FontWeight.w700, // font-bold
                        color: Color(0xFF0A192F), // text-navy
                        height: 1.1, // leading-tight
                      ),
                    ),
                    const SizedBox(height: 4), // mt-1
                    Row(
                      children: [
                        Text(
                          freelancer['role'] ?? '',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16, // text-base
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B), // text-slate
                          ),
                        ),
                        const SizedBox(width: 6), // gap-1.5
                        if (freelancer['verified'] == true)
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF10b77f), // text-primary
                            size: 16, // text-[16px]
                          ),
                      ],
                    ),
                    const SizedBox(height: 24), // mt-6

                    // Skills grid container
                if (freelancer['skills'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: (freelancer['skills'] as List<String>)
                          .map((skill) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  skill,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),

                // Stats Row Container
                Row(
                  children: [
                    _buildStatCard(
                      value: '${freelancer['projects'] ?? 0}',
                      label: 'PROJECTS',
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      value: '${freelancer['rating'] ?? 0}',
                      label: 'RATING',
                      icon: const Icon(Icons.star_rounded,
                          color: Color(0xFFF59E0B), size: 18),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      value: freelancer['responseTime'] ?? '-',
                      label: 'RESPONSE',
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // CTA Container
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF529F60),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      shadowColor: const Color(0xFF529F60).withValues(alpha: 0.3),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Hire ${freelancer['name']?.split(' ')[0]}',
                          style: const TextStyle(
                            fontFamily: 'Mona_Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_rounded, size: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The Avatar Breakout positioned relative to the stack
          Positioned(
            top: -40,
            left: 24,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: (freelancer['avatarPath'] != null)
                    ? Image.asset(
                        freelancer['avatarPath'],
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          freelancer['name']![0],
                          style: const TextStyle(
                            fontFamily: 'Mona_Sans',
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    Widget? icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FCFA),
          border: Border.all(color: const Color(0xFF529F60).withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Mona_Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.0,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 4),
                  icon,
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
