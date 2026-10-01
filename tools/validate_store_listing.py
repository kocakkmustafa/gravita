#!/usr/bin/env python3
"""Read-only course/catalogue claim gate for EN/TR local store drafts.

The public description is checked separately from its provenance metadata:
correct metadata cannot compensate for absent or incorrect public claims.
Historical STORE-LISTING-TASLAK catalogue counts remain a separate check.
No provider/store acceptance is inferred and no draft is rewritten.
"""
from copy import deepcopy
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LISTINGS = {'en': ROOT / 'docs/store/listing.json',
            'tr': ROOT / 'docs/store/listing.tr-TR.json'}
TASLAK_MD = ROOT / 'docs/store/STORE-LISTING-TASLAK.md'
LIBRARY = ROOT / 'content/library.json'
COURSE_PATH = 'content/courses/calisthenics.v1.json'
COURSE = ROOT / COURSE_PATH
PREPARATION_KEY = '$coursePreparation20260926'


def course_counts(course: dict) -> tuple[int, int]:
    modules = course['modules']
    return sum(len(module['lessons']) for module in modules), len(modules)


def claimed_course(text: str, language: str) -> tuple[int, int] | None:
    if language == 'en':
        lessons = re.search(r'\b(\d+)\s+(?:original\s+)?(?:English and Turkish\s+)?calisthenics lessons\b', text)
        modules = re.search(r'\bacross\s+(\d+)\s+modules\b', text)
    else:
        lessons = re.search(r'\b(\d+)\s+(?:özgün\s+)?(?:Türkçe ve İngilizce\s+)?calisthenics dersi\b', text)
        modules = re.search(r'\b(\d+)\s+modülde\b', text)
    if not lessons or not modules:
        return None
    return int(lessons.group(1)), int(modules.group(1))


def claimed_from_taslak_md(text: str) -> tuple[int, int, int] | None:
    match = re.search(r'(\d+) hareket,\s*(\d+) açık,\s*(\d+) ölçüm bekliyor', text)
    return tuple(map(int, match.groups())) if match else None


def check(listings: dict[str, dict], course: dict, source_sha: str,
          taslak_text: str, real_total: int, real_live: int) -> list[str]:
    """Pure gate; source content/hash and public/metadata claims are independent."""
    errors = []
    expected_counts = course_counts(course)
    if expected_counts[0] <= 0 or expected_counts[1] <= 0:
        errors.append('course: empty lesson/module source')
    for language in ('en', 'tr'):
        listing = listings.get(language)
        label = f'listing.{language}'
        if not isinstance(listing, dict):
            errors.append(f'{label}: missing draft')
            continue
        description = listing.get('description')
        claims = claimed_course(description, language) if isinstance(description, str) else None
        if claims is None:
            errors.append(f'{label}: public course count claim ABSENT; parser or copy must be reviewed')
        elif claims != expected_counts:
            errors.append(f'{label}: public lesson/module claim {claims}, source {expected_counts}')
        metadata = listing.get(PREPARATION_KEY)
        if not isinstance(metadata, dict):
            errors.append(f'{label}: source metadata ABSENT')
            continue
        expected = {'asset': COURSE_PATH, 'sha256': source_sha,
                    'lessonCount': expected_counts[0], 'moduleCount': expected_counts[1]}
        for field, value in expected.items():
            if metadata.get(field) != value:
                errors.append(f'{label}: source metadata {field}={metadata.get(field)!r}, expected {value!r}')
    catalogue_claim = claimed_from_taslak_md(taslak_text)
    expected_catalogue = real_total, real_live, real_total - real_live
    if catalogue_claim is None:
        errors.append('STORE-LISTING-TASLAK.md: catalogue claim ABSENT')
    elif catalogue_claim != expected_catalogue:
        errors.append(f'STORE-LISTING-TASLAK.md: catalogue {catalogue_claim}, source {expected_catalogue}')
    return errors


def self_test() -> int:
    # Synthetic source independent of either public description; no repo writes.
    course = {'modules': [{'lessons': [{}] * (6 if i < 6 else 5)} for i in range(10)]}
    source_sha = hashlib.sha256(json.dumps(course).encode()).hexdigest()
    counts = course_counts(course)
    assert counts == (56, 10)
    metadata = {'asset': COURSE_PATH, 'sha256': source_sha,
                'lessonCount': 56, 'moduleCount': 10}
    listings = {
        'en': {'description': '56 original English and Turkish calisthenics lessons across 10 modules.',
               PREPARATION_KEY: deepcopy(metadata)},
        'tr': {'description': '10 modülde 56 özgün Türkçe ve İngilizce calisthenics dersi.',
               PREPARATION_KEY: deepcopy(metadata)},
    }
    taslak = '| 31 hareket, 2 açık, 29 ölçüm bekliyor | kaynak |'
    def evaluate(value=listings, source=course, sha=source_sha, catalogue=taslak):
        return check(value, source, sha, catalogue, 31, 2)
    if evaluate():
        print('⛔ Positive bilingual source-bound control failed')
        return 1
    scenarios = []
    for language in ('en', 'tr'):
        bad = deepcopy(listings); bad[language]['description'] = bad[language]['description'].replace('56', '55')
        scenarios.append((f'{language} wrong public lesson count', evaluate(bad), f'listing.{language}: public'))
        bad = deepcopy(listings); bad[language]['description'] = 'Practice at your pace.'
        scenarios.append((f'{language} absent public course claim', evaluate(bad), f'listing.{language}: public'))
        bad = deepcopy(listings); bad[language][PREPARATION_KEY]['sha256'] = '0' * 64
        scenarios.append((f'{language} wrong source hash', evaluate(bad), 'sha256'))
        bad = deepcopy(listings); bad[language][PREPARATION_KEY]['moduleCount'] = 9
        scenarios.append((f'{language} wrong module metadata', evaluate(bad), 'moduleCount'))
        bad = deepcopy(listings); bad[language][PREPARATION_KEY]['lessonCount'] = 55
        scenarios.append((f'{language} wrong lesson metadata', evaluate(bad), 'lessonCount'))
    changed_source = deepcopy(course); changed_source['modules'][0]['lessons'].append({})
    scenarios.append(('source gained lesson while copy stayed stale', evaluate(source=changed_source), 'public'))
    scenarios.append(('legacy catalogue stale', evaluate(catalogue='31 hareket, 3 açık, 28 ölçüm bekliyor'), 'TASLAK.md'))
    scenarios.append(('legacy catalogue absent', evaluate(catalogue='Only a catalogue.'), 'TASLAK.md'))
    for name, errors, expected in scenarios:
        if not any(expected in error for error in errors):
            print(f'⛔ Negative control missed: {name}: {errors}')
            return 1
    print(f'✅ 1 positive + {len(scenarios)} negative controls passed; public claim, source count/hash and legacy catalogue independent')
    return 0


def main() -> int:
    if '--self-test' in sys.argv:
        return self_test()
    try:
        library = json.loads(LIBRARY.read_text(encoding='utf-8'))
        movements = library['movements']
        real_total = len(movements)
        real_live = sum(m.get('status') == 'live' for m in movements)
        raw_course = COURSE.read_bytes()
        course = json.loads(raw_course)
        errors = check({language: json.loads(path.read_text(encoding='utf-8'))
                        for language, path in LISTINGS.items()}, course,
                       hashlib.sha256(raw_course).hexdigest(),
                       TASLAK_MD.read_text(encoding='utf-8'), real_total, real_live)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'⛔ Source/draft cannot be read: {error}')
        return 1
    if errors:
        for error in errors:
            print(f'⛔ {error}')
        return 1
    lessons, modules = course_counts(course)
    print(f'✅ EN/TR draft claims + SHA match source {lessons} lessons/{modules} modules; legacy catalogue {real_total}/{real_live}/{real_total-real_live}. Local draft only.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
