// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:signature/signature.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

//==============================================================================
// PUNTO DE ENTRADA DE LA APLICACIÓN
//==============================================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

//==============================================================================
// WIDGET RAÍZ DE LA APLICACIÓN (MyApp)
//==============================================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JRB Productions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF007ACC),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007ACC),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2D2D2D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF007ACC)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

//==============================================================================
// PANTALLA PRINCIPAL (HomeScreen)
//==============================================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/logo wallpaper.jpg', height: 150),
              const SizedBox(height: 16),
              const Text(
                'JRB Film Productions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generador de Autorizaciones',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 64),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_document),
                label: const Text('Crear Nuevo Documento'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateDocumentScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Ver Documentos Guardados'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ViewDocumentsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//==============================================================================
// PANTALLA DE CREACIÓN DE DOCUMENTO (CreateDocumentScreen)
//==============================================================================

class CreateDocumentScreen extends StatefulWidget {
  const CreateDocumentScreen({super.key});

  @override
  State<CreateDocumentScreen> createState() => _CreateDocumentScreenState();
}

class _CreateDocumentScreenState extends State<CreateDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _ubicacionController = TextEditingController();

  bool _isLocating = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _dniController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Los servicios de ubicación están desactivados.')));
          setState(() => _isLocating = false);
          return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('El permiso de ubicación fue denegado.')));
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('El permiso de ubicación está denegado permanentemente.')));
        setState(() => _isLocating = false);
        return;
      }
      
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        _ubicacionController.text =
            "${place.locality ?? ''}, ${place.country ?? ''}";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener la ubicación: $e')));
    } finally {
      setState(() => _isLocating = false);
    }
  }

  void _proceedToSign() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignDocumentScreen(
            nombre: _nombreController.text,
            dni: _dniController.text,
            telefono: _telefonoController.text,
            email: _emailController.text,
            ubicacion: _ubicacionController.text,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos del Solicitante')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                  controller: _nombreController,
                  label: 'Nombre Completo',
                  icon: Icons.person),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _dniController, label: 'DNI', icon: Icons.badge),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _telefonoController,
                  label: 'Número de Teléfono',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField(
                  controller: _emailController,
                  label: 'Correo Electrónico',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'Por favor, introduce un email válido';
                    }
                    return null;
                  }),
              const SizedBox(height: 16),
              _buildLocationField(),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.draw),
                label: const Text('Continuar a la Firma'),
                onPressed: _proceedToSign,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
      ),
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: _ubicacionController,
      decoration: InputDecoration(
        labelText: 'Ubicación de la Firma',
        prefixIcon: const Icon(Icons.location_on, color: Colors.white70),
        suffixIcon: _isLocating
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: _getCurrentLocation,
                tooltip: 'Usar ubicación actual',
              ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'La ubicación es obligatoria';
        }
        return null;
      },
    );
  }
}

//==============================================================================
// PANTALLA DE FIRMA DEL DOCUMENTO (SignDocumentScreen)
//==============================================================================
class SignDocumentScreen extends StatefulWidget {
  final String nombre;
  final String dni;
  final String telefono;
  final String email;
  final String ubicacion;

  const SignDocumentScreen({
    super.key,
    required this.nombre,
    required this.dni,
    required this.telefono,
    required this.email,
    required this.ubicacion,
  });

  @override
  State<SignDocumentScreen> createState() => _SignDocumentScreenState();
}

class _SignDocumentScreenState extends State<SignDocumentScreen> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isSaving = false;

  String _buildDocumentText() {
    return '''
Autorización para Captura y Uso de Imágenes y Videos

Yo, ${widget.nombre}, mayor de edad, con DNI número ${widget.dni}, correo electrónico ${widget.email} y número de teléfono ${widget.telefono}, por medio de la presente declaro que otorgo plena autorización a JRB Film Productions, cámara y editor de foto y video, responsable de la cuenta de Instagram y página de Facebook de JRB Film Productions, para la captura de imágenes fotográficas y material audiovisual de mi persona durante el evento, sesión o actividad previamente acordada.

Esta autorización incluye la toma, edición, almacenamiento y uso tanto de fotografías como de videos obtenidos, con fines de difusión personal y promoción de su trabajo a través de sus redes sociales. En concreto, acepto que el material podrá ser compartido en la cuenta oficial de Instagram de JRB Film Productions y en su página de Facebook. Asimismo, se podrán compartir dichos contenidos conmigo como solicitante del servicio.

Declaro estar informado de que en caso de que yo decida publicar las imágenes o videos en mis propias redes sociales, me comprometo a etiquetar la cuenta oficial de Instagram de JRB Film Productions en cada publicación donde aparezca contenido generado durante esta colaboración.

Reconozco que esta autorización es otorgada de forma libre y voluntaria, y que no percibiré compensación económica alguna por el uso de las imágenes y videos. Eximo completamente a JRB Film Productions de cualquier responsabilidad legal, moral o económica por el uso presente o futuro del contenido capturado, incluyendo cualquier inconveniente o problema que pueda surgir posteriormente a la grabación o sesión fotográfica.

Este documento tiene validez legal y entra en vigor desde el momento de su firma, con vigencia indefinida salvo revocación expresa por escrito y notificada al responsable.
''';
  }

  Future<void> _generateAndSavePdf() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La firma es obligatoria para continuar.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final pdfBytes = await PdfGenerator.generatePdf(
        nombre: widget.nombre,
        dni: widget.dni,
        telefono: widget.telefono,
        email: widget.email,
        ubicacion: widget.ubicacion,
        documentText: _buildDocumentText(),
        signatureBytes: signatureBytes!,
      );

      final status = await Permission.storage.request();
      if (status.isGranted) {
        final directory = await getExternalStoragePublicDirectory();
        final path = '${directory.path}/${widget.nombre.replaceAll(' ', '_')}.pdf';
        final file = File(path);
        await file.writeAsBytes(pdfBytes);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF guardado en: $path'),
          duration: const Duration(seconds: 5),
        ));
        
        Navigator.of(context).popUntil((route) => route.isFirst);

      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permiso de almacenamiento denegado.'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      print("Error al generar PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al generar el PDF: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<Directory> getExternalStoragePublicDirectory() async {
    if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        final documentsDir = Directory('${directory!.path}/Documentos Firmados');
        if (!await documentsDir.exists()) {
          await documentsDir.create(recursive: true);
        }
        return documentsDir;
    }
    return await getApplicationDocumentsDirectory();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firmar Documento')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                _buildDocumentText(),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text("Firme en el recuadro", style: Theme.of(context).textTheme.bodyMedium),
          ),
          Container(
            height: 150,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey),
            ),
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                  onPressed: () => _signatureController.clear(),
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
                        : const Icon(Icons.check),
                    label: Text(_isSaving ? 'Guardando...' : 'Completar y Guardar'),
                    onPressed: _isSaving ? null : _generateAndSavePdf,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//==============================================================================
// PANTALLA DE VISUALIZACIÓN DE DOCUMENTOS (ViewDocumentsScreen)
//==============================================================================
class ViewDocumentsScreen extends StatefulWidget {
  const ViewDocumentsScreen({super.key});

  @override
  State<ViewDocumentsScreen> createState() => _ViewDocumentsScreenState();
}

class _ViewDocumentsScreenState extends State<ViewDocumentsScreen> {
  late Future<List<FileSystemEntity>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _documentsFuture = _loadDocuments();
  }

  Future<List<FileSystemEntity>> _loadDocuments() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      try {
        final directory = await getExternalStoragePublicDirectory();
        final files = directory.listSync();
        files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        return files.where((file) => file.path.endsWith('.pdf')).toList();
      } catch (e) {
        print("Error cargando documentos: $e");
        return [];
      }
    }
    return [];
  }
  
  Future<Directory> getExternalStoragePublicDirectory() async {
    if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        final documentsDir = Directory('${directory!.path}/Documentos Firmados');
        if (!await documentsDir.exists()) {
          await documentsDir.create(recursive: true);
        }
        return documentsDir;
    }
    return await getApplicationDocumentsDirectory();
  }

  void _refreshDocuments() {
    setState(() {
      _documentsFuture = _loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos Guardados'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshDocuments)],
      ),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _documentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No se encontraron documentos.', style: TextStyle(color: Colors.white70)));
          }

          final documents = snapshot.data!;
          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final file = documents[index];
              final fileName = file.path.split('/').last;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  title: Text(fileName.replaceAll('.pdf', '')),
                  subtitle: Text('Modificado: ${DateFormat('dd/MM/yyyy HH:mm').format(file.statSync().modified)}'),
                  onTap: () => OpenFile.open(file.path),
                  trailing: IconButton(
                    icon: const Icon(Icons.share, color: Colors.white70),
                    onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'Autorización firmada: $fileName'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

//==============================================================================
// SERVICIO DE GENERACIÓN DE PDF (PdfGenerator)
//==============================================================================

class PdfGenerator {
  static Future<Uint8List> generatePdf({
    required String nombre,
    required String dni,
    required String telefono,
    required String email,
    required String ubicacion,
    required String documentText,
    required Uint8List signatureBytes,
  }) async {
    final pdf = pw.Document(
        author: 'JRB Film Productions', title: 'Autorizacion - $nombre');
    
    final logoImageBytes = await rootBundle.load('assets/logo wallpaper.jpg');
    final logoImage = pw.MemoryImage(logoImageBytes.buffer.asUint8List());

    final prefs = await SharedPreferences.getInstance();
    int docCounter = (prefs.getInt('docCounter') ?? 0) + 1;
    await prefs.setInt('docCounter', docCounter);
    final docId = 'JRB-${DateTime.now().year}-${docCounter.toString().padLeft(4, '0')}';

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      buildBackground: (context) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Center(
          child: pw.Opacity(
            opacity: 0.05,
            child: pw.Image(logoImage, height: 400),
          ),
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (context) => [
          _buildHeader(logoImage, docId),
          pw.SizedBox(height: 20),
          pw.Text(documentText, textAlign: pw.TextAlign.justify),
          pw.SizedBox(height: 40),
          _buildFooter(
            nombre: nombre,
            ubicacion: ubicacion,
            signatureImage: pw.MemoryImage(signatureBytes),
          ),
        ],
        footer: (context) => _buildPageFooter(),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(pw.MemoryImage logo, String docId) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Image(logo, height: 80),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('JRB Film Productions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.Text('Documento de Autorización'),
            pw.SizedBox(height: 8),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(), 
              data: 'ID: $docId',
              width: 50,
              height: 50,
            ),
            pw.Text(docId, style: const pw.TextStyle(fontSize: 8)),
          ]
        ),
      ],
    );
  }

  static pw.Widget _buildFooter({
    required String nombre,
    required String ubicacion,
    required pw.MemoryImage signatureImage,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('El presente documento se firma en $ubicacion con fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.SizedBox(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(signatureImage, height: 50),
                  pw.Divider(color: PdfColors.black, height: 5),
                  pw.Text('Firma: $nombre'),
                ]
              )
            )
          ]
        ),
      ]
    );
  }

  static pw.Widget _buildPageFooter() {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'JRB Film Productions © ${DateTime.now().year} - Documento generado digitalmente',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );
  }
}

