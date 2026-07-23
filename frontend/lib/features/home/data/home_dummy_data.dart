/// Hardcoded dummy data for homepage sections.
///
/// These are used as fallback when the API returns empty results.
/// Users can replace the image paths with their own images in assets/images/
/// and assets/avatars/ respectively.
const List<Map<String, String>> kDummyProjects = [
  {
    'title': 'Geologi',
    'author': 'Klass Curated',
    'imagePath': 'assets/images/ppt_geologi.png',
    'ratio': 'ppt',
  },
  {
    'title': 'Biologi',
    'author': 'Klass Curated',
    'imagePath': 'assets/images/ppt_biologi.png',
    'ratio': 'ppt',
  },
  {
    'title': 'Kalkulus',
    'author': 'Klass Curated',
    'imagePath': 'assets/images/ppt_kalkulus.png',
    'ratio': 'ppt',
  },
  {
    'title': 'Pendidikan Pancasila',
    'author': 'Klass Curated',
    'imagePath': 'assets/images/ppt_pancasila.png',
    'ratio': 'ppt',
  },
];

const List<Map<String, dynamic>> kDummyFreelancers = [
  {'name': 'Agus Pratama', 'avatarPath': 'assets/avatars/agus.png'},
  {'name': 'Ani Wulandari', 'avatarPath': 'assets/avatars/ani.png'},
  {'name': 'Budi Santoso', 'avatarPath': 'assets/avatars/budi.png'},
  {'name': 'Susi Rahmawati', 'avatarPath': 'assets/avatars/susi.png'},
];
