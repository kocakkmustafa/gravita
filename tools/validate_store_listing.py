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
# Seven first-release courses in five skill areas (GRV-04, 2026-10-26).
CATALOGUE_PATHS = [COURSE_PATH] + [f'content/courses/{name}.v1.json' for name in (
    'dbkb-written', 'dbkb-handling', 'dbkb-transitions',
    'barbell-foundations', 'rings-foundations', 'hands-foundations')]


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


def free_lessons(course: dict) -> int:
    """Paywall A, same rule as lib/app/paywall_policy.dart freeLessonCount."""
    sizes = [len(module['lessons']) for module in course['modules']]
    third = -(-sum(sizes) // 3)
    if len(sizes) <= 1:
        return third
    covered = 0
    for size in sizes:
        if covered >= third:
            break
        covered += size
    return covered


def catalogue_counts(courses: list[dict]) -> tuple[int, int, int]:
    """(courses, lessons, free lessons) across the first-release catalogue."""
    return (len(courses), sum(course_counts(c)[0] for c in courses),
            sum(free_lessons(c) for c in courses))


def claimed_catalogue(text: str, language: str) -> tuple[int, int, int] | None:
    if language == 'en':
        total = re.search(r'\bfive skill areas with (\d+) original English and Turkish written lessons in (\d+) courses\b', text)
        free = re.search(r'\b(\d+) of (\d+) lessons in total\b', text)
        if not total or not free or free.group(2) != total.group(1):
            return None
        return int(total.group(2)), int(total.group(1)), int(free.group(1))
    total = re.search(r'\bbeş beceri alanında (\d+) kursta (\d+) özgün Türkçe ve İngilizce yazılı dersle\b', text)
    free = re.search(r"\b[Tt]oplam (\d+) dersin (\d+)'[a-zçğıöşü]+\b", text)
    if not total or not free or free.group(1) != total.group(2):
        return None
    return int(total.group(1)), int(total.group(2)), int(free.group(2))


def claimed_from_taslak_md(text: str) -> tuple[int, int, int] | None:
    match = re.search(r'(\d+) hareket,\s*(\d+) açık,\s*(\d+) ölçüm bekliyor', text)
    return tuple(map(int, match.groups())) if match else None


def check(listings: dict[str, dict], course: dict, source_sha: str,
          taslak_text: str, real_total: int, real_live: int,
          catalogue: list[dict] | None = None) -> list[str]:
    """Pure gate; source content/hash and public/metadata claims are independent."""
    errors = []
    expected_catalogue_counts = catalogue_counts(catalogue) if catalogue is not None else None
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
        if expected_catalogue_counts is not None:
            totals = claimed_catalogue(description, language) if isinstance(description, str) else None
            if totals is None:
                errors.append(f'{label}: public catalogue/free-lesson claim ABSENT; parser or copy must be reviewed')
            elif totals != expected_catalogue_counts:
                errors.append(f'{label}: public courses/lessons/free claim {totals}, source {expected_catalogue_counts}')
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
    # Synthetic two-course catalogue: 56 + 12 lessons, 24 + 4 free (68/28).
    small = {'modules': [{'lessons': [{}] * 4} for _ in range(3)]}
    courses = [course, small]
    assert catalogue_counts(courses) == (2, 68, 28)
    listings['en']['description'] += (' Gravita teaches five skill areas with 68 original English and Turkish written lessons in 2 courses.'
                                      ' The first part is free, 28 of 68 lessons in total.')
    listings['tr']['description'] += (' Gravita beş beceri alanında 2 kursta 68 özgün Türkçe ve İngilizce yazılı dersle öğretir.'
                                      " Toplam 68 dersin 28'i ücretsizdir.")
    def evaluate(value=listings, source=course, sha=source_sha, catalogue=taslak, cat=courses):
        return check(value, source, sha, catalogue, 31, 2, cat)
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
        bad = deepcopy(listings); bad[language]['description'] = bad[language]['description'].replace('28', '27')
        scenarios.append((f'{language} wrong free-lesson claim', evaluate(bad), 'courses/lessons/free'))
        bad = deepcopy(listings); bad[language]['description'] = bad[language]['description'].replace('in 2 courses', 'in 3 courses').replace('2 kursta', '3 kursta')
        scenarios.append((f'{language} wrong course count', evaluate(bad), 'courses/lessons/free'))
        bad = deepcopy(listings); bad[language]['description'] = bad[language]['description'].split(' Gravita ')[0]
        scenarios.append((f'{language} absent catalogue claim', evaluate(bad), 'catalogue/free-lesson claim ABSENT'))
    changed_source = deepcopy(course); changed_source['modules'][0]['lessons'].append({})
    scenarios.append(('source gained lesson while copy stayed stale', evaluate(source=changed_source), 'public'))
    scenarios.append(('catalogue gained lesson while copy stayed stale',
                      evaluate(cat=[course, {'modules': [{'lessons': [{}] * 5}] + small['modules'][1:]}]), 'courses/lessons/free'))
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
        catalogue = [json.loads((ROOT / path).read_text(encoding='utf-8')) for path in CATALOGUE_PATHS]
        errors = check({language: json.loads(path.read_text(encoding='utf-8'))
                        for language, path in LISTINGS.items()}, course,
                       hashlib.sha256(raw_course).hexdigest(),
                       TASLAK_MD.read_text(encoding='utf-8'), real_total, real_live, catalogue)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'⛔ Source/draft cannot be read: {error}')
        return 1
    if errors:
        for error in errors:
            print(f'⛔ {error}')
        return 1
    lessons, modules = course_counts(course)
    n_courses, n_lessons, n_free = catalogue_counts(catalogue)
    print(f'✅ EN/TR draft claims + SHA match source {lessons} lessons/{modules} modules; catalogue {n_courses} courses/{n_lessons} lessons/{n_free} free; legacy catalogue {real_total}/{real_live}/{real_total-real_live}. Local draft only.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
