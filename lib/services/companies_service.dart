import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/company.dart';
import 'api/api_service.dart';

class CompaniesPage {
  final List<Company> companies;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const CompaniesPage({
    required this.companies,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

class CompaniesService {
  final ApiService apiService;

  CompaniesService(this.apiService);

  Future<CompaniesPage> fetchCompanies({
    required String slug,
    required int page,
    required int limit,
    required String search,
  }) async {
    try {
      final path = slug == 'gestalk' ? '/company' : '/company/slug/$slug';
      final response = await apiService.dio.get<dynamic>(
        path,
        queryParameters: slug == 'gestalk'
            ? {
                'page': page,
                'limit': limit,
                if (search.trim().isNotEmpty) 'search': search.trim(),
              }
            : null,
      );

      final data = response.data;
      final rawCompanies = data is Map ? data['companies'] : null;
      final rawCompany = data is Map ? data['company'] : null;
      final rawPagination = data is Map ? data['pagination'] : null;

      final companies = rawCompanies is List
          ? rawCompanies
              .whereType<Map>()
              .map((item) => Company.fromJson(Map<String, dynamic>.from(item)))
              .where((company) => company.id.isNotEmpty)
              .toList()
          : rawCompany is Map
              ? [Company.fromJson(Map<String, dynamic>.from(rawCompany))]
                  .where((company) => company.id.isNotEmpty)
                  .toList()
              : <Company>[];

      final pagination = rawPagination is Map
          ? Map<String, dynamic>.from(rawPagination)
          : const <String, dynamic>{};

      return CompaniesPage(
        companies: companies,
        total: _int(pagination['total'], companies.length),
        page: _int(pagination['page'], page),
        limit: _int(pagination['limit'], limit),
        totalPages: _int(pagination['totalPages'], 1),
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar empresas.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<Company> fetchCompany(String companyId) async {
    try {
      final response = await apiService.dio.get<dynamic>('/company/$companyId');
      final data = response.data;
      final rawCompany = data is Map ? data['company'] : null;

      if (rawCompany is! Map) {
        throw ApiException('Empresa não encontrada.');
      }

      return Company.fromJson(Map<String, dynamic>.from(rawCompany));
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar empresa.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<List<CompanyPlanOption>> fetchPlans() async {
    try {
      final response = await apiService.dio.get<dynamic>('/plan/actives');
      final data = response.data;
      final rawPlans = data is Map ? data['plans'] : null;

      if (rawPlans is! List) return [];

      return rawPlans
          .whereType<Map>()
          .map((item) => CompanyPlanOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
              ))
          .where((plan) => plan.id.isNotEmpty)
          .toList();
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar planos.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<String> uploadImage(String filePath) async {
    try {
      final data = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'upload_preset': 'my-uploads',
      });

      final response = await Dio().post<dynamic>(
        'https://api.cloudinary.com/v1_1/dnoj3gfqd/image/upload',
        data: data,
      );

      final url = response.data is Map ? response.data['url'] : null;
      if (url == null || url.toString().isEmpty) {
        throw ApiException('Erro ao enviar imagem.');
      }

      return url.toString();
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao enviar imagem.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<Company> saveCompany({
    required String? companyId,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> customizationPayload,
  }) async {
    try {
      final response = companyId == null || companyId.isEmpty
          ? await apiService.dio.post<dynamic>('/company', data: payload)
          : await apiService.dio.patch<dynamic>(
              '/company/$companyId',
              data: payload,
            );

      final data = response.data;
      final rawCompany = data is Map ? data['company'] : null;

      if (rawCompany is! Map) {
        throw ApiException('Empresa não retornada pelo servidor.');
      }

      final company = Company.fromJson(Map<String, dynamic>.from(rawCompany));
      final customizationPath = companyId == null || companyId.isEmpty
          ? '/customization'
          : '/customization/company/$companyId';

      await apiService.dio.request<dynamic>(
        customizationPath,
        data: {
          ...customizationPayload,
          'companyId': company.id,
        },
        options: Options(
            method: companyId == null || companyId.isEmpty ? 'POST' : 'PATCH'),
      );

      return company;
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao salvar empresa.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }
}

int _int(dynamic value, int fallback) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _message(DioException error, {required String fallback}) {
  final data = error.response?.data;
  if (data is Map) {
    final message = data['message'] ?? data['error'];
    if (message is List && message.isNotEmpty) return message.first.toString();
    if (message != null && message.toString().isNotEmpty) {
      return message.toString();
    }
  }
  return fallback;
}
