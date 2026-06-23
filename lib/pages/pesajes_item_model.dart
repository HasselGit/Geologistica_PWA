import 'package:flutter/material.dart';
import '../flutter_flow/flutter_flow_util.dart';

class PesajesItemModel {
  String? scannedValue;
  String? tmpSenasa;
  TextEditingController? textController;
  FocusNode? textFieldFocusNode;
  String? Function(BuildContext, String?)? textControllerValidator;

  TextEditingController? brutoController;
  TextEditingController? taraController;

  void dispose() {
    textController?.dispose();
    textFieldFocusNode?.dispose();
    brutoController?.dispose();
    taraController?.dispose();
  }
}
