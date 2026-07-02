import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/exceptions/api_exception.dart';
import '../models/channel.dart';
import '../services/channels_service.dart';

class ChannelsController extends ChangeNotifier {
  final ChannelsService channelsService;

  ChannelsController({required this.channelsService});

  Timer? _searchDebounce;
  List<Channel> channels = [];
  String searchTerm = '';
  String statusFilter = 'active';
  bool loading = false;
  String? error;
  int total = 0;
  int page = 1;
  int limit = 20;
  int totalPages = 1;

  bool get canGoPrevious => page > 1 && !loading;
  bool get canGoNext => page < totalPages && !loading;

  Future<void> load({String? companyId, bool resetPage = false}) async {
    if (resetPage) page = 1;

    loading = true;
    error = null;
    notifyListeners();

    try {
      final result = await channelsService.fetchChannels(
        status: statusFilter,
        page: page,
        limit: limit,
        search: companyId == null || companyId.isEmpty ? searchTerm : '',
        companyId: companyId,
      );

      channels = result.channels;
      total = result.total;
      page = result.page;
      limit = result.limit;
      totalPages = result.totalPages == 0 ? 1 : result.totalPages;
    } on ApiException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Erro ao carregar canais.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({String? companyId}) {
    return load(companyId: companyId);
  }

  Future<void> setStatusFilter(String value, {String? companyId}) async {
    statusFilter = value;
    await load(companyId: companyId, resetPage: true);
  }

  void setSearchTerm(String value) {
    searchTerm = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      load(resetPage: true);
    });
    notifyListeners();
  }

  Future<void> nextPage({String? companyId}) async {
    if (!canGoNext) return;
    page += 1;
    await load(companyId: companyId);
  }

  Future<void> previousPage({String? companyId}) async {
    if (!canGoPrevious) return;
    page -= 1;
    await load(companyId: companyId);
  }

  Future<void> firstPage({String? companyId}) async {
    if (page == 1 || loading) return;
    page = 1;
    await load(companyId: companyId);
  }

  Future<void> lastPage({String? companyId}) async {
    if (page == totalPages || loading) return;
    page = totalPages;
    await load(companyId: companyId);
  }

  Future<void> saveChannel({
    required String? channelId,
    required String name,
    required String companyId,
    required bool isPrivated,
    required bool isInative,
  }) {
    if (channelId == null || channelId.isEmpty) {
      return channelsService.createChannel(
        name: name,
        companyId: companyId,
        isPrivated: isPrivated,
        isInative: isInative,
      );
    }

    return channelsService.updateChannel(
      channelId: channelId,
      name: name,
      companyId: companyId,
      isPrivated: isPrivated,
      isInative: isInative,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
