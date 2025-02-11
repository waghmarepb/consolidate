// main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

class DataListScreen extends StatefulWidget {
  const DataListScreen({super.key});

  @override
  DataListScreenState createState() => DataListScreenState();
}

class DataListScreenState extends State<DataListScreen> {
  List<dynamic> _data = [];
  bool _isLoading = true;
  String _error = '';
  final ScrollController _horizontalScrollController = ScrollController();
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  int _perPage = 10;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  final List<String> columns = [
    'Doc No',
    'Registration Date',
    'SRO Code',
    'Internal Doc No',
    'Doc Name',
    'SRO Name',
    'MICR No',
    'Bank Type',
    'Party Code',
    'Seller Party',
    'Purchaser Party',
    'Property Description',
    'Area Name',
    'Consideration Amount',
    'Market Value',
    'Date of Execution',
    'Stamp Duty Paid',
    'Registration Fees',
    'Status',
    'File Name',
    'Upload Date',
  ];

  final Map<String, String> columnToField = {
    'Doc No': 'docno',
    'Registration Date': 'registrationdate',
    'SRO Code': 'srocode',
    'Internal Doc No': 'internaldocumentnumber',
    'Doc Name': 'docname',
    'SRO Name': 'sroname',
    'MICR No': 'micrno',
    'Bank Type': 'bank_type',
    'Party Code': 'party_code',
    'Seller Party': 'sellerparty',
    'Purchaser Party': 'purchaserparty',
    'Property Description': 'propertydescription',
    'Area Name': 'areaname',
    'Consideration Amount': 'consideration_amt',
    'Market Value': 'marketvalue',
    'Date of Execution': 'dateofexecution',
    'Stamp Duty Paid': 'stampdutypaid',
    'Registration Fees': 'registrationfees',
    'Status': 'status',
    'File Name': 'file_name',
    'Upload Date': 'upload_date',
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
            'http://127.0.0.1:5000/api/data/list?page=$_currentPage&per_page=$_perPage'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _data = jsonResponse['data'];
          _totalPages = jsonResponse['total_pages'] ?? 1;
          _totalRecords = jsonResponse['total'] ?? 0;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAllData() async {
    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:5000/api/data/delete-all'),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _data = [];
          _totalRecords = 0;
          _totalPages = 1;
          _currentPage = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted successfully')),
        );
      } else {
        throw Exception('Failed to delete data');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error deleting data: $e';
      });
    }
  }

  Future<void> _downloadPDF() async {
    try {
      final pdf = pw.Document();

      // Add title page
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child:
                    pw.Text('Data Report', style: pw.TextStyle(fontSize: 24)),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                headers: columns,
                data: _data
                    .map((item) => columns
                        .map((column) =>
                            item[columnToField[column]]?.toString() ?? 'N/A')
                        .toList())
                    .toList(),
              ),
            ],
          ),
        ),
      );

      // Save the PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/data_report.pdf');
      await file.writeAsBytes(await pdf.save());

      // Open the PDF
      await OpenFile.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF downloaded successfully')),
      );
    } catch (e) {
      setState(() {
        _error = 'Error downloading PDF: $e';
      });
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Data'),
          content: const Text(
            'Are you sure you want to delete all data? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAllData();
              },
            ),
          ],
        );
      },
    );
  }

  List<dynamic> get filteredData {
    if (searchQuery.isEmpty) return _data;
    return _data.where((item) {
      final String docNo = item['docno']?.toString().toLowerCase() ?? '';
      final String sellerParty =
          item['sellerparty']?.toString().toLowerCase() ?? '';
      final String purchaserParty =
          item['purchaserparty']?.toString().toLowerCase() ?? '';
      return docNo.contains(searchQuery.toLowerCase()) ||
          sellerParty.contains(searchQuery.toLowerCase()) ||
          purchaserParty.contains(searchQuery.toLowerCase());
    }).toList();
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Records: $_totalRecords',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage = 1;
                        });
                        _fetchData();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                        _fetchData();
                      }
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Page $_currentPage of $_totalPages',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                        _fetchData();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage = _totalPages;
                        });
                        _fetchData();
                      }
                    : null,
              ),
              const SizedBox(width: 20),
              DropdownButton<int>(
                value: _perPage,
                items: [10, 20, 50, 100].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value per page'),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _perPage = newValue;
                      _currentPage = 1;
                    });
                    _fetchData();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Search by Doc No, Seller, or Purchaser',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _showDeleteConfirmationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete All'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _downloadPDF,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF'),
                ),
              ],
            ),
          ),
          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[100],
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error,
                      style: TextStyle(color: Colors.red[900]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _error = '';
                      });
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading && _data.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Scrollbar(
                    controller: _horizontalScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          columns: columns
                              .map((column) => DataColumn(
                                    label: Text(
                                      column,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ))
                              .toList(),
                          rows: filteredData
                              .map(
                                (item) => DataRow(
                                  cells: columns
                                      .map((column) => DataCell(
                                            Text(
                                              item[columnToField[column]]
                                                      ?.toString() ??
                                                  'N/A',
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    searchController.dispose();
    super.dispose();
  }
}
