import 'package:dio/dio.dart';

import '../core/exceptions/api_exception.dart';
import '../models/channel.dart';
import 'api/api_service.dart';

class ChannelCompanyOption {
  final String id;
  final String name;

  const ChannelCompanyOption({
    required this.id,
    required this.name,
  });
}

class ChannelsPage {
  final List<Channel> channels;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const ChannelsPage({
    required this.channels,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

class ChannelsService {
  final ApiService apiService;

  ChannelsService(this.apiService);

  Future<ChannelsPage> fetchChannels({
    required String status,
    required int page,
    required int limit,
    required String search,
    String? companyId,
  }) async {
    try {
      final path = companyId != null && companyId.isNotEmpty
          ? '/channels/company/$companyId'
          : switch (status) {
              'active' => '/channels/active',
              'inactive' => '/channels/inactive',
              _ => '/channels',
            };

      final response = await apiService.dio.get<dynamic>(
        path,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (companyId == null || companyId.isEmpty)
            if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      final data = response.data;
      final rawChannels = data is Map ? data['channels'] : null;
      final rawPagination = data is Map ? data['pagination'] : null;

      final channels = rawChannels is List
          ? rawChannels
              .whereType<Map>()
              .map((item) => Channel.fromJson(Map<String, dynamic>.from(item)))
              .where((channel) => channel.id.isNotEmpty)
              .toList()
          : <Channel>[];

      final pagination = rawPagination is Map
          ? Map<String, dynamic>.from(rawPagination)
          : const <String, dynamic>{};

      return ChannelsPage(
        channels: channels,
        total: _int(pagination['total'], channels.length),
        page: _int(pagination['page'], page),
        limit: _int(pagination['limit'], limit),
        totalPages: _int(pagination['totalPages'], 1),
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar canais.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<Channel> fetchChannel(String channelId) async {
    try {
      final response =
          await apiService.dio.get<dynamic>('/channels/$channelId');
      final data = response.data;
      final rawChannel = data is Map ? data['channels'] : null;

      if (rawChannel is! Map) {
        throw ApiException('Canal não encontrado.');
      }

      return Channel.fromJson(Map<String, dynamic>.from(rawChannel));
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar canal.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<List<ChannelCompanyOption>> fetchCompanies(String slug) async {
    try {
      if (slug != 'gestalk') {
        final response = await apiService.dio.get<dynamic>(
          '/company/slug/$slug',
        );
        final data = response.data;
        final company = data is Map ? data['company'] : null;

        if (company is! Map) return [];

        final option = _companyOption(Map<String, dynamic>.from(company));
        return option.id.isEmpty ? [] : [option];
      }

      final response = await apiService.dio.get<dynamic>(
        '/company',
        queryParameters: {
          'page': 1,
          'limit': 100,
        },
      );
      final data = response.data;
      final rawCompanies = data is Map ? data['companies'] : null;

      if (rawCompanies is! List) return [];

      return rawCompanies
          .whereType<Map>()
          .map((item) => _companyOption(Map<String, dynamic>.from(item)))
          .where((company) => company.id.isNotEmpty)
          .toList();
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao buscar empresas.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> createChannel({
    required String name,
    required String companyId,
    required bool isPrivated,
    required bool isInative,
  }) async {
    try {
      await apiService.dio.post<dynamic>(
        '/channels',
        data: {
          'name': name,
          'companyId': companyId,
          'isPrivated': isPrivated,
          'isInative': isInative,
        },
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao criar canal.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }

  Future<void> updateChannel({
    required String channelId,
    required String name,
    required String companyId,
    required bool isPrivated,
    required bool isInative,
  }) async {
    try {
      await apiService.dio.patch<dynamic>(
        '/channels/$channelId',
        data: {
          'name': name,
          'companyId': companyId,
          'isPrivated': isPrivated,
          'isInative': isInative,
        },
      );
    } on DioException catch (error) {
      throw ApiException(
        _message(error, fallback: 'Erro ao atualizar canal.'),
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }
  }
}

ChannelCompanyOption _companyOption(Map<String, dynamic> json) {
  return ChannelCompanyOption(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
  );
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
