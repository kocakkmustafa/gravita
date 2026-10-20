import 'package:flutter/material.dart';
import 'app_locale.dart';
import 'calisthenics_course_screen.dart';
import 'content_repository.dart';
import 'theme.dart';

class FoundationCourseEntry extends StatelessWidget {
  const FoundationCourseEntry({required this.content, super.key});
  final ContentRepository content;
  @override
  Widget build(BuildContext context) => GravitaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localized(
            context,
            'Three foundation pathways',
            'Üç temel öğrenme yolu',
          ),
          style: GravitaType.display(context: context, size: 20),
        ),
        Text(
          localized(
            context,
            'Work through the original beginner sequences, with the stated equipment checks, small practice options and easier paths. Learning reports do not validate physical performance; movement feedback requires separate calibration.',
            'Özgün başlangıç sıralarını belirtilen ekipman kontrolleri,küçük pratik seçenekleri ve kolay yollarla çalış. Öğrenme bildirimi fiziksel performansı doğrulamaz;hareket geri bildirimi ayrı kalibrasyon ister.',
          ),
        ),
        for (final entry in content.foundationCourses.entries)
          TextButton.icon(
            key: Key('foundation.entry.${entry.key}'),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(
              entry.value.title.inLanguage(
                Localizations.localeOf(context).toLanguageTag(),
              ),
            ),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => CalisthenicsCourseScreen(
                  course: entry.value,
                  modelManifest: content.observationManifest,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
