// lib/services/vendor_dashboard_service.dart
import '../models/vendor_dashboard.dart';
import 'api_client.dart';

class VendorDashboardService {
  final ApiClient _api;

  VendorDashboardService({required ApiClient apiClient}) : _api = apiClient;

  Future<VendorDashboard> getDashboard() async {
    final json = await _api.get('/vendor/dashboard', auth: true);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return VendorDashboard.fromJson(data);
  }
}
