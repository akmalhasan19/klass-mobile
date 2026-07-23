import 'dart:io';

void main() async {
  HttpOverrides.global = _MyOverrides();
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('https://pub-7ec094e10eed491fb2160f17e582f8bf.r2.dev/assets/ppt_geologi.jpg'));
  req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
  req.headers.set('Accept', 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8');
  req.headers.set('Accept-Language', 'en-US,en;q=0.9');
  req.headers.set('Accept-Encoding', 'gzip, deflate, br');
  req.headers.set('Sec-Fetch-Dest', 'image');
  req.headers.set('Sec-Fetch-Mode', 'no-cors');
  req.headers.set('Sec-Fetch-Site', 'cross-site');

  final res = await req.close();
  print('STATUS: ${res.statusCode}');
  final bytes = await res.expand((b) => b).toList();
  try {
    print('STRING: ${String.fromCharCodes(bytes.take(100))}');
  } catch(e) {}
}

class _MyOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..badCertificateCallback = ((c,h,p)=>true);
}
