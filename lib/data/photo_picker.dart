import 'package:image_picker/image_picker.dart';

/// Abstração da captura de fotos: os testes substituem por [FakePhotoPicker]
/// e nada depende de câmera física.
abstract interface class PhotoPicker {
  /// Devolve o identificador da foto, ou `null` se o usuário cancelou.
  Future<String?> pick();
}

/// Implementação real (câmera). Por enquanto devolve o caminho local do
/// arquivo: o upload para o storage entra junto com a fatia de fotos do backend.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick() async {
    final file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600);
    return file?.path;
  }
}

/// Usada em testes e no modo demonstração.
class FakePhotoPicker implements PhotoPicker {
  int _n = 0;

  @override
  Future<String?> pick() async => 'foto-${++_n}.jpg';
}
