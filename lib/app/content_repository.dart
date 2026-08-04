import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:gravita_engine/gravita_engine.dart';
import 'package:path_provider/path_provider.dart';

/// İçerik + kalıcılık KABLOLAMASI — kabuğun motora bakan tek yüzü.
///
/// **Neden burada:** motor (`gravita_engine`) saf Dart'tır ve dosya sistemini de
/// asset bundle'ı da bilmez. Bu sınıf "nereden okunur" sorusunu cevaplar, "ne
/// anlama gelir" sorusuna KARIŞMAZ — türetme motorun `LessonSurface.deriveAll`
/// fonksiyonunda, tek evde (G-079 dersi: aynı ölçümün iki evi tutarsızlaşır).
///
/// `JsonlSessionStore` bir `File` alır; `path_provider` çağrısı BU katmanda
/// kalır. Terfi-arayüzünün 1. şartı budur (`docs/design/SESSION-STORE-DELTA.md`
/// §0): depo saf Dart, KABLOLAMA Flutter.
final class ContentRepository {
  ContentRepository._({
    required this.library,
    required this.lessonSurfaces,
    required Map<String, MovementConfig> catalog,
  }) : _catalog = catalog;

  /// İçeriği asset bundle'dan yükler.
  ///
  /// Katalog dosyası ADRESİ hareketin kendi `wave` alanından kurulur —
  /// `content/catalog/w1` SABİTLEMEK, G-099'da üç yerde birden bulunan
  /// dalga-körlüğünün aynısı olurdu. Dosya bundle'da yoksa yükleme GÜRÜLTÜLÜ
  /// patlar; sessizce boş liste dönmek dersleri yüzeyden sessizce düşürürdü.
  static Future<ContentRepository> load(AssetBundle bundle) async {
    final Map<String, dynamic> lib =
        (jsonDecode(await bundle.loadString('content/library.json')) as Map)
            .cast<String, dynamic>();

    final Map<String, MovementConfig> catalog = <String, MovementConfig>{};
    for (final Map<String, dynamic> m
        in (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final String catalogId = (m['catalogId'] ?? m['id']) as String;
      final String? wave = m['wave'] as String?;
      if (wave == null) {
        throw StateError(
            'library.json: ${m['id']} `wave` bildirmiyor — katalog adresi '
            'kurulamaz. Dalga beyanı zorunlu.');
      }
      catalog[catalogId] = MovementConfig.parse(await bundle
          .loadString('content/catalog/${wave.toLowerCase()}/$catalogId.json'));
    }

    return ContentRepository._(
      library: lib,
      catalog: catalog,
      lessonSurfaces: LessonSurface.deriveAll(
        library: lib,
        catalogFor: (String id) => catalog[id]!,
      ),
    );
  }

  final Map<String, dynamic> library;

  /// Yüzeyin BUGÜN bildiği dersler — kilitliler DAHİL (M-F-168 kural 2).
  final List<LessonSurface> lessonSurfaces;

  final Map<String, MovementConfig> _catalog;

  /// Yüklenen tüm hareket config'leri — canlı yol seçimi için (kimlik ön
  /// koşulu türetilmiş olanı arar). Kopya döner: katalog dışarıdan
  /// değiştirilemez.
  List<MovementConfig> get movementConfigs =>
      List<MovementConfig>.unmodifiable(_catalog.values);

  MovementConfig? movementConfig(String catalogId) => _catalog[catalogId];

  /// Seans geçmişi deposu. Dosya uygulama-özel dizinde; biçim motorda.
  static Future<SessionStore> openSessionStore() async {
    final Directory dir = await getApplicationSupportDirectory();
    return JsonlSessionStore(File('${dir.path}/sessions.jsonl'));
  }
}
