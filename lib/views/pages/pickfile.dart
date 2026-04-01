import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class Pickfile extends StatefulWidget {
  const Pickfile({super.key});

  @override
  State<Pickfile> createState() => _PickfileState();
}

class _PickfileState extends State<Pickfile> {
  Future<void> pickFile() async {

    try{
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);

      print("File selcteed: ${file.path}");
      } else {
        print("No file selected");
      }
    } catch (e) {
      print("Error picking file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}
