import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class MockData {
  // --- Home Screen Mock Data ---
  static final List<Map<String, dynamic>> projects = [
    {
      'title': 'Modern History of Indonesia',
      'author': 'By Antigravity',
      'ratio': 'ppt',
      'imagePath': 'assets/images/ppt_design_3.jpg',
      'description':
          'Explore the journey of Indonesia from the colonial era to the modern age. This project covers key historical events, the struggle for independence, and the development of the nation. Perfect for students and history enthusiasts looking to understand the roots of contemporary Indonesia.',
      'tags': ['History', 'Indonesia', 'Education'],
      'type': 'PPT',
      'modules': [
        {'title': 'Masa Kolonial Belanda', 'detail': '2 Slides'},
        {'title': 'Perjuangan Kemerdekaan', 'detail': '3 Slides'},
        {'title': 'Era Orde Lama & Baru', 'detail': '2 Slides'},
        {'title': 'Indonesia Modern', 'detail': '1 Slide'}
      ],
    },
    {
      'title': 'Benefits of Healthy Eating',
      'author': 'By Antigravity',
      'ratio': 'infographic',
      'imagePath': 'assets/images/infographic_preview_health_1773981088610.png',
      'description':
          'Discover how nutrition impacts your daily life and long-term health. This infographic project breaks down complex dietary concepts into easy-to-understand visuals, covering vitamins, minerals, and the importance of a balanced diet. Great for health campaigns and personal awareness.',
      'tags': ['Health', 'Nutrition', 'Design'],
      'type': 'Infographic',
      'modules': [
        {'title': 'Pentingnya Makronutrien', 'detail': 'Karbo, Protein, Lemak'},
        {'title': 'Mikronutrien Esensial', 'detail': 'Vitamin & Mineral'},
        {'title': 'Dampak Jangka Panjang', 'detail': 'Pencegahan Penyakit'}
      ],
    },
    {
      'title': 'Mathematics Quiz',
      'author': 'By Antigravity',
      'ratio': 'square',
      'imagePath': 'assets/images/square_preview_math_1773981103817.png',
      'description':
          'A fun and interactive way to test your mathematical skills. Covering algebra, geometry, and basic arithmetic, this project is designed to challenge students and make learning math enjoyable through gamification and clear visual feedback.',
      'tags': ['Math', 'Quiz', 'Learning'],
      'type': 'Quiz',
      'modules': [
        {'title': 'Aljabar Dasar', 'detail': '5 Pertanyaan'},
        {'title': 'Geometri', 'detail': '4 Pertanyaan'},
        {'title': 'Aritmatika Lanjut', 'detail': '6 Pertanyaan'}
      ],
    },
  ];

  static final List<Map<String, dynamic>> freelancers = [
    {
      'name': 'Agus S',
      'avatarPath': 'assets/avatars/agus.png',
      'role': 'Advanced Mathematics Tutor',
      'rate': 45,
      'skills': ['Calculus', 'SAT Prep', 'Algebra', 'Physics'],
      'projects': 42,
      'rating': 4.9,
      'responseTime': '< 1h',
      'verified': true,
      'scale': 1.1,
    },
    {
      'name': 'Ani A',
      'avatarPath': 'assets/avatars/ani.png',
      'role': 'Creative Graphic Designer',
      'rate': 35,
      'skills': ['UI/UX', 'Illustration', 'Branding', 'Figma'],
      'projects': 28,
      'rating': 4.8,
      'responseTime': '< 2h',
      'verified': true,
      'scale': 1.1,
    },
    {
      'name': 'Budi O',
      'avatarPath': 'assets/avatars/budi.png',
      'role': 'Fullstack Web Developer',
      'rate': 55,
      'skills': ['Next.js', 'TypeScript', 'Node.js', 'Tailwind'],
      'projects': 56,
      'rating': 5.0,
      'responseTime': '< 30m',
      'verified': true,
      'scale': 1.3,
    },
    {
      'name': 'Susi',
      'avatarPath': 'assets/avatars/susi.png',
      'role': 'English Language Specialist',
      'rate': 30,
      'skills': ['IELTS', 'TOEFL', 'Business English', 'Writing'],
      'projects': 34,
      'rating': 4.7,
      'responseTime': '< 3h',
      'verified': false,
      'scale': 1.2,
    },
  ];

  // --- Search Screen Mock Data ---
  static final List<Map<String, dynamic>> searchCategories = [
    {'name': 'All', 'icon': Icons.grid_view_rounded},
    {'name': 'Science', 'icon': Icons.science_rounded},
    {'name': 'Math', 'icon': Icons.calculate_rounded},
    {'name': 'Art', 'icon': Icons.palette_rounded},
    {'name': 'Code', 'icon': Icons.code_rounded},
    {'name': 'History', 'icon': Icons.menu_book_rounded},
  ];

  static final List<Map<String, dynamic>> searchTeachers = [
    {
      'name': 'Elena Rodriguez',
      'role': 'Sr. UX/UI Designer / Art Teacher',
      'rating': 4.9,
      'tags': ['Wireframing', 'Prototyping', 'Figma'],
      'description':
          'Helping startups build intuitive and beautiful digital products. Available for short-term sprints.',
      'online': true,
    },
    {
      'name': 'Marcus Chen',
      'role': 'Full-stack Developer / Coding Mentor',
      'rating': 5.0,
      'tags': ['React', 'Node.js', 'Tailwind'],
      'description':
          'Expert in building scalable web applications. Passionate about teaching modern web technologies.',
      'online': false,
    },
  ];

  // --- Profile Screen Mock Data ---
  static final List<Map<String, dynamic>> profileModules = [
    {
      'title': 'Intro to Quantum Physics',
      'description':
          'A comprehensive journey from classical mechanics to the mysteries of quantum entanglements.',
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBTGKxSjUWwWvC2HvRdzg_RmvbCSLmCQH4UIU84ACn48uxwjyucMwK_wWVloZS99Ija6TT0Qr8yWPeti7JYBlEwelvNYlUTZ_rv5tQTZ7JqQ6H3oNIAjgCk0zGA_mjuh7FMYP92E5O8iA1zAiciFWoMTuFEqFxvhiNq5-i5tpKHdoI03HZphV9FcfsUUrzuu6vLitJfPtQVkvJ9Jxmcfzz8dyBwk2dJylV8Scjv6d22YZpLbpnRh1EQjmki4XCJ5iaz61XHKpHUxusQ',
      'status': 'Published',
      'isDraft': false,
      'stats': [
        const Icon(Icons.group_rounded, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        const Text('1.2k', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(width: 16),
        const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        const Text('14h', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    },
    {
      'title': 'Modern Art History',
      'description':
          'Exploring the seismic shifts in artistic expression from the mid-19th century to today.',
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAE7PoZ9LTIoG5uutNqz6Xt6gD2YUvbqq305GgIp-hfioQTmG3nGy3Oueh2HGA6A0lCtP1lUmn17dyLJ2gaphosdX3DwcPgBMk8-EhDHoMWq3WmL5pVaYXw_ohoMasfJV49PFhNeIJ1Tn7i1lyKuPxvoofnIF63eoOciRZ7wDUKCpxezigtDmQajbBiTf0jU1Xi1hIUeXxYJphhgn96vCQIJencrKhiN9HuG1j5gprRDmnP4ETdGnst1cXyPh1pVICDPNqoGZHywo7g',
      'status': 'Published',
      'isDraft': false,
      'stats': [
        const Icon(Icons.group_rounded, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        const Text('850', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(width: 16),
        const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        const Text('8h', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    },
    {
      'title': 'Advanced Thermodynamics',
      'description':
          'In-depth analysis of entropy, enthalpy, and energy conversion systems.',
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCR6hR6bvffsyKtu12OhoJs6jMLIN6XlZ7V_c10UhZ4NnbX-CVQzaD48EjnPlC_ZG76rC7T7d82o5F7bBRsNmeezOeU7-Rmtkn_BXIU88LmGYkaduQGJhsEZHbEYkvc0x_Jpll2b4-3oBvv0b0V711JUu--D242lHRWTM0pPN6dZVKx8kON4x5QfsP4d_kRrzv0gyf6WyyKFkKbkjcHPqQq3PUtcf3K1lrg-j-6jPoH3dZo_H62th4HDgoOU9K8Jzv-2LMxpn0Lcwnj',
      'status': 'Draft',
      'isDraft': true,
      'stats': [
        const Icon(Icons.history_edu_rounded, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        const Text('4/12 Modules', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    },
  ];
}
