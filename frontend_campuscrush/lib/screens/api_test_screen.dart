import 'package:flutter/material.dart';
import 'dart:async';
import '../core/constants/app_constants.dart';
import '../services/api_connection_test.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({Key? key}) : super(key: key);

  @override
  ApiTestScreenState createState() => ApiTestScreenState();
}

class ApiTestScreenState extends State<ApiTestScreen> {
  bool _isLoading = false;
  String _resultMessage = '';
  bool _isSuccess = false;
  int? _statusCode;
  String _responseBody = '';

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _resultMessage = 'Testing connection to ${AppConstants.baseUrl}...';
      _isSuccess = false;
      _statusCode = null;
      _responseBody = '';
    });

    try {
      // First, try the health endpoint
      final result = await ApiConnectionTest.testConnection(
          '${AppConstants.baseUrl}${AppConstants.healthEndpoint}');

      setState(() {
        _isLoading = false;
        _isSuccess = result['success'] ?? false;
        _statusCode = result['statusCode'];
        _resultMessage = result['message'] ?? 'Unknown result';
        _responseBody = result['data'] != null
            ? result['data'].toString()
            : 'No response data';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _resultMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _testRootEndpoint() async {
    setState(() {
      _isLoading = true;
      _resultMessage = 'Testing connection to ${AppConstants.baseUrl}...';
      _isSuccess = false;
      _statusCode = null;
      _responseBody = '';
    });

    try {
      // Try the root endpoint
      final result =
          await ApiConnectionTest.testConnection(AppConstants.baseUrl);

      setState(() {
        _isLoading = false;
        _isSuccess = result['success'] ?? false;
        _statusCode = result['statusCode'];
        _resultMessage = result['message'] ?? 'Unknown result';
        _responseBody = result['data'] != null
            ? result['data'].toString()
            : 'No response data';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _resultMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Connection Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Server Address:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(AppConstants.baseUrl),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _testRootEndpoint,
              child: const Text('Test Root Endpoint (/)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              child: const Text('Test Health Endpoint (/api/v1/users/me)'),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Result:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isSuccess
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSuccess ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isSuccess ? Icons.check_circle : Icons.error,
                              color: _isSuccess ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _resultMessage,
                                style: TextStyle(
                                  color: _isSuccess ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_statusCode != null) ...[
                          const SizedBox(height: 8),
                          Text('Status Code: $_statusCode'),
                        ],
                        if (_responseBody.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Response:'),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            width: double.infinity,
                            child: SingleChildScrollView(
                              child: Text(
                                _responseBody,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
