import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class FileUploadState {
  final String fileName;
  final int fileSize;
  final String filePath;
  double progress;
  String status;
  String? error;
  final DateTime addedTime;

  FileUploadState({
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    this.progress = 0,
    this.status = 'Pending',
    this.error,
    DateTime? addedTime,
  }) : this.addedTime = addedTime ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'fileSize': fileSize,
      'filePath': filePath,
      'progress': progress,
      'status': status,
      'error': error,
      'addedTime': addedTime.toIso8601String(),
    };
  }

  factory FileUploadState.fromJson(Map<String, dynamic> json) {
    try {
      return FileUploadState(
        fileName: json['fileName']?.toString() ?? '',
        fileSize: json['fileSize'] is int ? json['fileSize'] : 0,
        filePath: json['filePath']?.toString() ?? '',
        progress: (json['progress'] is num)
            ? (json['progress'] as num).toDouble()
            : 0.0,
        status: json['status']?.toString() ?? 'Pending',
        error: json['error']?.toString(),
        addedTime: json['addedTime'] != null
            ? DateTime.tryParse(json['addedTime'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
    } catch (e) {
      // If there's any error in parsing, return a default state
      return FileUploadState(
        fileName: 'Unknown File',
        fileSize: 0,
        filePath: '',
        status: 'Error',
        error: 'Error parsing file data',
      );
    }
  }
}

class UploadPage extends StatefulWidget {
  const UploadPage({Key? key}) : super(key: key);

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  List<FileUploadState> _files = [];
  String? _error;
  late SharedPreferences _prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSavedFiles();
    } catch (e) {
      print('Error initializing preferences: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedFiles() async {
    try {
      final savedFiles = _prefs.getStringList('uploadedFiles') ?? [];
      final loadedFiles = <FileUploadState>[];

      for (final fileJson in savedFiles) {
        try {
          final jsonData = json.decode(fileJson);
          if (jsonData is Map<String, dynamic>) {
            loadedFiles.add(FileUploadState.fromJson(jsonData));
          }
        } catch (e) {
          print('Error parsing file data: $e');
        }
      }

      setState(() {
        _files = loadedFiles
          ..sort((a, b) => b.addedTime.compareTo(a.addedTime));
      });
    } catch (e) {
      print('Error loading saved files: $e');
      setState(() {
        _error = 'Error loading saved files';
      });
    }
  }

  Future<void> _saveFiles() async {
    try {
      final fileJsonList =
          _files.map((file) => json.encode(file.toJson())).toList();
      await _prefs.setStringList('uploadedFiles', fileJsonList);
    } catch (e) {
      print('Error saving files: $e');
      setState(() {
        _error = 'Error saving files';
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null) {
        setState(() {
          _files.insertAll(
            0,
            result.files.map((file) => FileUploadState(
                  fileName: file.name,
                  fileSize: file.size,
                  filePath: file.path ?? '',
                )),
          );
          _error = null;
        });

        await _saveFiles();

        for (var fileState in _files.take(result.files.length)) {
          if (fileState.status == 'Pending') {
            await _uploadFile(fileState);
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error picking files: $e';
      });
    }
  }

  Future<void> _uploadFile(FileUploadState fileState) async {
    final url = Uri.parse('http://127.0.0.1:5000/api/files/upload');

    try {
      setState(() {
        fileState.status = 'Uploading';
      });
      await _saveFiles();

      final file = await File(fileState.filePath).readAsBytes();

      final request = http.MultipartRequest('POST', url);

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        file,
        filename: fileState.fileName,
        contentType: MediaType('application',
            'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      );

      request.files.add(multipartFile);
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);

        setState(() {
          fileState.status = 'Completed';
          fileState.progress = 1.0;
        });
        await _saveFiles();
      } else {
        final responseData = await response.stream.bytesToString();
        final errorData = json.decode(responseData);
        throw Exception(errorData['error'] ?? 'Upload failed');
      }
    } catch (e) {
      setState(() {
        fileState.status = 'Failed';
        fileState.error = e.toString();
      });
      await _saveFiles();
    }
  }

  Future<void> _removeFile(int index) async {
    setState(() {
      _files.removeAt(index);
    });
    await _saveFiles();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Failed':
        return Colors.red;
      case 'Uploading':
        return const Color(0xFFFF6B00);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            if (_files.isNotEmpty) ...[
              Expanded(
                child: Card(
                  child: ListView.separated(
                    itemCount: _files.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final fileState = _files[index];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(fileState.fileName),
                            subtitle: Text(_formatFileSize(fileState.fileSize)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(fileState.status)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    fileState.status,
                                    style: TextStyle(
                                      color: _getStatusColor(fileState.status),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  color: Colors.red,
                                  onPressed: () => _removeFile(index),
                                ),
                              ],
                            ),
                          ),
                          if (fileState.status == 'Uploading' ||
                              fileState.status == 'Completed')
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: LinearProgressIndicator(
                                value: fileState.progress,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    fileState.status == 'Completed'
                                        ? Colors.green
                                        : const Color(0xFFFF6B00)),
                              ),
                            ),
                          if (fileState.error != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                fileState.error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickFiles,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Add File'),
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
      ),
    );
  }
}
