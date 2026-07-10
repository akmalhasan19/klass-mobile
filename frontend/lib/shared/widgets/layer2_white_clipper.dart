import 'package:flutter/material.dart';

/// Clipper untuk Background Putih (Layer 2) yang memotong area atas dan ujung kanan-atas
/// sehingga "Layer 1" (hijau) yang berada di belakangnya terekspos.
class Layer2WhiteClipper extends CustomClipper<Path> {
  // cutOffY mengatur besarnya "garis lurus (horizontal)" di bagian atas text "Klass".
  // Nilai ini juga memendekkan "garis vertikal" dari blob hijau.
  final double cutOffY;

  Layer2WhiteClipper({this.cutOffY = 24.0});

  @override
  Path getClip(Size size) {
    Path path = Path();
    double w = size.width;
    double h = size.height;

    // Lebar total blob hijau terekspos = 140
    // Tinggi total blob hijau terekspos = 173
    double blobWidth = 140.0;
    
    // Titik pertemuan sisi melengkung dengan ujung lurus
    double leftX = w - blobWidth; 
    
    // Radius lengkungan atas-kiri dari blobnya (garis vertikalnya turun sepanjang rc)
    double rc = 30.0; 
    double vertX = leftX + rc; // w - 110
    
    // Titik pertemuan ujung vertikal ke bawah dengan lengkungan bawah-kiri convex
    double rv = 45.0; 
    double blobTotalHeight = 173.0;

    // Path Layer 2 (Area Putih):
    // Mulai dari Kiri Atas layar, yang sudah turun sebesar cutOffY.
    // Ini membentuk garis lurus memanjang horizontal di atas text "Klass"
    path.moveTo(0, cutOffY);
    path.lineTo(leftX, cutOffY);

    // Convex curve: membentuk lengkungan flare atas-kiri blob (green) di sudut White shape.
    // Sisi atas white shape (horizontal) "berbelok" ke sisi vertikal.
    path.quadraticBezierTo(vertX, cutOffY, vertX, cutOffY + rc);

    // Garis vertikal lurus ke bawah untuk sisi kiri blob (green).
    // Karena kita memakai cutOffY, panjang garis vertikal ini = (blobTotalHeight - rc - rv) - cutOffY
    path.lineTo(vertX, blobTotalHeight - rc - rv);

    // Concave curve: membentuk convex bottom-left dari blob (green).
    // Bagi area white (kanan/bawah garis ini) bentuk ini mencekung masuk.
    path.quadraticBezierTo(vertX, blobTotalHeight - rc, vertX + rv, blobTotalHeight - rc);

    // Garis lurus horizontal sepanjang dasar blob (green).
    path.lineTo(w - rc, blobTotalHeight - rc);

    // Convex curve: membentuk concave bottom-right flare dari blob (green).
    path.quadraticBezierTo(w, blobTotalHeight - rc, w, blobTotalHeight);

    // Sisi lurus vertikal layar ke ujung kanan bawah
    path.lineTo(w, h);
    
    // Garis sejajar bagian bawah layar kembali ke sudut kiri bawah
    path.lineTo(0, h);
    
    // Tutup path dengan garis lurus kembali ke kiri atas
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant Layer2WhiteClipper oldClipper) {
    return oldClipper.cutOffY != cutOffY;
  }
}
