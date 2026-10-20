import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Read-only Shoonya market-feed client.
///
/// Authentication is deliberately external: this class accepts a short-lived
/// access token from a separately implemented, approved OAuth flow. It never
/// logs tokens and exposes no order-placement methods.
class ShoonyaQuote {
  const ShoonyaQuote({
    required this.exchange,
    required this.token,
    required this.receivedAt,
    required this.fields,
  });

  final String exchange;
  final String token;
  final DateTime receivedAt;
  final Map<String, dynamic> fields;

  String get key => '$exchange|$token';
  String? get symbol => fields['ts']?.toString();
  double? get lastPrice {
    final value = fields['lp'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? get feedEpochSeconds {
    final value = fields['ft'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

/// WebSocket-only quote client. The caller must resolve each holding to a
/// Shoonya exchange/token pair and must refresh authentication after expiry.
class ShoonyaQuoteService {
  ShoonyaQuoteService({
    required this.userId,
    required this.accountId,
    required this.accessToken,
    this.source = 'API',
  });

  static final Uri _endpoint = Uri.parse('wss://api.shoonya.com/NorenWSAPI/');

  final String userId;
  final String accountId;
  final String accessToken;
  final String source;

  final StreamController<ShoonyaQuote> _quotes =
      StreamController<ShoonyaQuote>.broadcast();
  final Map<String, Map<String, dynamic>> _cache = {};
  final Set<String> _subscriptions = {};
  WebSocket? _socket;
  bool _disposed = false;
  bool _authenticated = false;

  Stream<ShoonyaQuote> get quotes => _quotes.stream;
  bool get isConnected => _socket?.readyState == WebSocket.open;
  Map<String, Map<String, dynamic>> get snapshot =>
      Map.unmodifiable(_cache.map((key, value) =>
          MapEntry(key, Map<String, dynamic>.unmodifiable(value))));

  /// Opens the feed and subscribes to [exchangeTokenPairs] after the
  /// successful connect acknowledgement. Pair format: 'NSE|token'.
  Future<void> connect(Iterable<String> exchangeTokenPairs) async {
    if (_disposed) throw StateError('ShoonyaQuoteService is disposed');
    _subscriptions
      ..clear()
      ..addAll(exchangeTokenPairs.map((e) => e.trim()).where(_validPair));
    if (_subscriptions.isEmpty) {
      throw ArgumentError('At least one valid EXCHANGE|TOKEN pair is required');
    }
    await disconnect();
    final socket = await WebSocket.connect(_endpoint.toString());
    if (_disposed) {
      await socket.close();
      return;
    }
    _socket = socket;
    _authenticated = false;
    socket.listen(
      _handleMessage,
      onError: (Object error, StackTrace stack) {
        _authenticated = false;
      },
      onDone: () {
        _authenticated = false;
        if (identical(_socket, socket)) _socket = null;
      },
      cancelOnError: false,
    );
    socket.add(jsonEncode({
      't': 'a',
      'uid': userId,
      'actid': accountId,
      'source': source,
      'accesstoken': accessToken,
    }));
  }

  bool _validPair(String pair) {
    final parts = pair.split('|');
    return parts.length == 2 && parts.every((part) => part.trim().isNotEmpty);
  }

  void _handleMessage(dynamic raw) {
    if (_disposed || raw is! String) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final message = Map<String, dynamic>.from(decoded);
    final type = message['t']?.toString();

    // Connect ack is different from the per-instrument quote snapshot.
    if (type == 'ak') {
      if (message['s']?.toString().toLowerCase() != 'ok') {
        _authenticated = false;
        return;
      }
      _authenticated = true;
      _sendSubscriptions();
      return;
    }
    if (!_authenticated || (type != 'tk' && type != 'tf')) return;

    final exchange = message['e']?.toString();
    final token = message['tk']?.toString();
    if (exchange == null || token == null) return;
    final key = '$exchange|$token';
    if (!_subscriptions.contains(key)) return;

    // Shoonya sends a full 'tk' snapshot, then 'tf' diffs. Merge every update
    // so omitted fields remain available to the UI.
    final merged = _cache.putIfAbsent(key, () => <String, dynamic>{});
    merged.addAll(message);
    _quotes.add(ShoonyaQuote(
      exchange: exchange,
      token: token,
      receivedAt: DateTime.now(),
      fields: Map<String, dynamic>.unmodifiable(merged),
    ));
  }

  void _sendSubscriptions() {
    final socket = _socket;
    if (!_authenticated || socket == null || socket.readyState != WebSocket.open) {
      return;
    }
    // Shoonya uses # separators in a batched subscription frame.
    socket.add(jsonEncode({'t': 't', 'k': _subscriptions.join('#')}));
  }

  /// Re-subscribes after reconnect. Call [connect] again after socket loss;
  /// callers should implement bounded exponential backoff and re-authenticate
  /// if the session has expired.
  Future<void> disconnect() async {
    _authenticated = false;
    final socket = _socket;
    _socket = null;
    if (socket != null) await socket.close();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _quotes.close();
    _cache.clear();
    _subscriptions.clear();
  }
}
