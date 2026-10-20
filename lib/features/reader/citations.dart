// Pure citation logic: find in-text citation markers ("[12]", "[3-5, 9]",
// "(Vaswani et al., 2017)", "Smith (2020)"), parse the references section
// of a paper and resolve a marker to its reference entries. No widgets;
// unit-tested in test/reader/citations_test.dart.

import 'package:meta/meta.dart';

enum CitationStyle { numeric, authorYear }

/// One author-year item ("Vaswani et al., 2017").
typedef AuthorYear = ({String author, String year});

@immutable
class CitationMarker {
  const CitationMarker({
    required this.raw,
    required this.start,
    required this.end,
    required this.style,
    this.numbers = const <int>[],
    this.authorYears = const <AuthorYear>[],
  });

  /// The marker as printed, e.g. `[12]` or `(Smith, 2020)`.
  final String raw;

  /// Char range `[start, end)` of [raw] in the page text.
  final int start;
  final int end;
  final CitationStyle style;

  /// Reference numbers for numeric markers (ranges expanded).
  final List<int> numbers;

  /// Items for author-year markers.
  final List<AuthorYear> authorYears;

  @override
  bool operator ==(Object other) =>
      other is CitationMarker &&
      other.raw == raw &&
      other.start == start &&
      other.end == end &&
      other.style == style &&
      _eq(other.numbers, numbers) &&
      _eq(other.authorYears, authorYears);

  @override
  int get hashCode => Object.hash(raw, start, end, style);

  @override
  String toString() => 'CitationMarker($raw @ $start..$end)';
}

/// One entry of the references section.
@immutable
class ReferenceEntry {
  const ReferenceEntry({
    required this.text,
    required this.pageNumber,
    this.label,
  });

  /// Printed label ("12" for "[12]" / "12."), null for author-year lists.
  final String? label;

  /// Entry text, whitespace-collapsed.
  final String text;

  /// 1-based page the entry starts on.
  final int pageNumber;

  @override
  bool operator ==(Object other) =>
      other is ReferenceEntry &&
      other.label == label &&
      other.text == text &&
      other.pageNumber == pageNumber;

  @override
  int get hashCode => Object.hash(label, text, pageNumber);

  @override
  String toString() => 'ReferenceEntry($label, p$pageNumber, $text)';
}

const String _dash = r'[-–—]';
final RegExp _numericMarker = RegExp(
  r'\[\s*(\d{1,4}(?:\s*' +
      _dash +
      r'\s*\d{1,4})?(?:\s*[,;]\s*\d{1,4}(?:\s*' +
      _dash +
      r'\s*\d{1,4})?)*)\s*\]',
);
final RegExp _parenGroup = RegExp(r'\(([^()\n]{4,240})\)');
const String _surname =
    r"(?:(?:van|von|de|del|der|da|di|le|la)\s+)?\p{Lu}[\p{L}'’\-]+";
final RegExp _authorYearItem = RegExp(
  '($_surname(?:\\s+(?:et\\s+al\\.?|(?:and|&)\\s+$_surname))?)'
  r',?\s+((?:1[89]|20)\d{2}[a-z]?)',
  unicode: true,
);
final RegExp _yearOnly = RegExp(
  r'^\s*((?:1[89]|20)\d{2}[a-z]?)(?:\s*[,;]\s*((?:1[89]|20)\d{2}[a-z]?))*\s*$',
);
final RegExp _year = RegExp(r'(?:1[89]|20)\d{2}[a-z]?');
final RegExp _narrativeAuthor = RegExp(
  '($_surname(?:\\s+(?:et\\s+al\\.?|(?:and|&)\\s+$_surname))?)\\s*\$',
  unicode: true,
);

List<int> _expandNumbers(String body) {
  final out = <int>[];
  for (final part in body.split(RegExp(r'[,;]'))) {
    final range = part.split(RegExp(_dash));
    final a = int.tryParse(range.first.trim());
    if (a == null) continue;
    if (range.length > 1) {
      final b = int.tryParse(range.last.trim());
      if (b != null && b >= a && b - a <= 200) {
        for (var n = a; n <= b; n++) {
          out.add(n);
        }
        continue;
      }
    }
    out.add(a);
  }
  return out;
}

/// All citation markers in [text], in order.
List<CitationMarker> findCitationMarkers(String text) {
  final out = <CitationMarker>[];
  for (final m in _numericMarker.allMatches(text)) {
    final numbers = _expandNumbers(m[1]!);
    if (numbers.isEmpty) continue;
    out.add(
      CitationMarker(
        raw: m[0]!,
        start: m.start,
        end: m.end,
        style: CitationStyle.numeric,
        numbers: numbers,
      ),
    );
  }
  for (final m in _parenGroup.allMatches(text)) {
    final body = m[1]!;
    final items = <AuthorYear>[];
    for (final part in body.split(';')) {
      final item = _authorYearItem.firstMatch(part);
      if (item != null) {
        items.add((author: _cleanAuthor(item[1]!), year: item[2]!));
      }
    }
    var start = m.start;
    if (items.isEmpty && _yearOnly.hasMatch(body)) {
      // Narrative form: "Smith et al. (2020)" -> author before the paren.
      final before = text.substring((m.start - 80).clamp(0, m.start), m.start);
      final author = _narrativeAuthor.firstMatch(before);
      if (author != null) {
        start = m.start - (before.length - author.start);
        for (final y in _year.allMatches(body)) {
          items.add((author: _cleanAuthor(author[1]!), year: y[0]!));
        }
      }
    }
    if (items.isEmpty) continue;
    out.add(
      CitationMarker(
        raw: text.substring(start, m.end),
        start: start,
        end: m.end,
        style: CitationStyle.authorYear,
        authorYears: items,
      ),
    );
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

String _cleanAuthor(String a) => a.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The citation marker covering char [index] of [text], or null. Taps a
/// char or two outside the brackets still count ([slop]).
CitationMarker? citationMarkerAt(String text, int index, {int slop = 1}) {
  if (index < 0 || index > text.length) return null;
  for (final m in findCitationMarkers(text)) {
    if (index >= m.start - slop && index < m.end + slop) return m;
  }
  return null;
}

final RegExp _referencesHeading = RegExp(
  r'(?:^|\n)[ \t]*(?:[0-9IVX]+\.?[ \t]*)?'
  r'(References|REFERENCES|Bibliography|BIBLIOGRAPHY|Works Cited|Literature Cited|R\s?E\s?F\s?E\s?R\s?E\s?N\s?C\s?E\s?S)'
  r'[ \t]*(?=\n|$)',
);
final RegExp _sectionAfterReferences = RegExp(
  r'\n[ \t]*(?:[A-Z][ \t.]+)?(Appendix|APPENDIX|Appendices|APPENDICES|Supplementary Material|SUPPLEMENTARY)\b',
);
final RegExp _bracketLabel = RegExp(r'(?:^|\n)[ \t]*\[(\d{1,4})\][ \t]*');
final RegExp _dotLabel = RegExp(
  r'(?:^|\n)[ \t]*(\d{1,4})\.[ \t]+(?=\p{Lu})',
  unicode: true,
);
final RegExp _authorYearEntryStart = RegExp(
  '\\n[ \\t]*(?=$_surname,\\s+(?:\\p{Lu}\\.|\\p{Lu}[\\p{L}\\-]+))',
  unicode: true,
);

/// Parses the references section from the page texts ([pages] in page
/// order). Returns an empty list when no references heading is found.
List<ReferenceEntry> parseReferences(
  List<({int pageNumber, String text})> pages,
) {
  if (pages.isEmpty) return const <ReferenceEntry>[];
  final buffer = StringBuffer();
  final pageStarts = <({int offset, int pageNumber})>[];
  for (final p in pages) {
    pageStarts.add((offset: buffer.length, pageNumber: p.pageNumber));
    buffer
      ..write(p.text)
      ..write('\n');
  }
  final all = buffer.toString();
  final headings = _referencesHeading.allMatches(all).toList();
  if (headings.isEmpty) return const <ReferenceEntry>[];
  final sectionStart = headings.last.end;
  var sectionEnd = all.length;
  final after = _sectionAfterReferences.firstMatch(all.substring(sectionStart));
  if (after != null) sectionEnd = sectionStart + after.start;
  final section = all.substring(sectionStart, sectionEnd);

  int pageAt(int offset) {
    var page = pageStarts.first.pageNumber;
    for (final s in pageStarts) {
      if (s.offset <= offset) page = s.pageNumber;
    }
    return page;
  }

  ReferenceEntry entry(String? label, int from, int to) => ReferenceEntry(
    label: label,
    text: section.substring(from, to).replaceAll(RegExp(r'\s+'), ' ').trim(),
    pageNumber: pageAt(sectionStart + from),
  );

  List<ReferenceEntry> labelled(List<RegExpMatch> marks) => <ReferenceEntry>[
    for (var i = 0; i < marks.length; i++)
      entry(
        marks[i][1],
        marks[i].end,
        i + 1 < marks.length ? marks[i + 1].start : section.length,
      ),
  ].where((e) => e.text.isNotEmpty).toList(growable: false);

  final brackets = _bracketLabel.allMatches(section).toList();
  if (brackets.length >= 2) return labelled(brackets);
  final dots = _sequential(_dotLabel.allMatches(section).toList());
  if (dots.length >= 2) return labelled(dots);

  // Author-year: an entry starts on a line beginning "Surname, I." or
  // "Surname, Given".
  final starts = <int>[
    0,
    ..._authorYearEntryStart.allMatches(section).map((m) => m.start),
  ];
  final entries = <ReferenceEntry>[];
  for (var i = 0; i < starts.length; i++) {
    final e = entry(
      null,
      starts[i],
      i + 1 < starts.length ? starts[i + 1] : section.length,
    );
    if (e.text.isNotEmpty) entries.add(e);
  }
  return entries;
}

/// Keeps "N." labels only while they count up 1, 2, 3… (filters out
/// numbered list items and stray "2019." lines).
List<RegExpMatch> _sequential(List<RegExpMatch> marks) {
  final out = <RegExpMatch>[];
  var expected = 1;
  for (final m in marks) {
    if (int.parse(m[1]!) == expected) {
      out.add(m);
      expected++;
    }
  }
  return out;
}

/// The reference entries [marker] points at (empty when unresolvable).
List<ReferenceEntry> resolveCitation(
  CitationMarker marker,
  List<ReferenceEntry> references,
) {
  switch (marker.style) {
    case CitationStyle.numeric:
      return <ReferenceEntry>[
        for (final n in marker.numbers)
          ...references.where((r) => r.label == '$n').take(1),
      ];
    case CitationStyle.authorYear:
      final out = <ReferenceEntry>[];
      for (final item in marker.authorYears) {
        final surname = item.author
            .split(RegExp(r'\s+(?:et\s+al\.?|and|&)\s*'))
            .first
            .trim()
            .toLowerCase();
        final match = references.where((r) {
          final t = r.text.toLowerCase();
          return t.contains(surname) && t.contains(item.year.toLowerCase());
        }).toList();
        // Prefer an entry that starts with the surname (first author).
        match.sort(
          (a, b) => (a.text.toLowerCase().startsWith(surname) ? 0 : 1)
              .compareTo(b.text.toLowerCase().startsWith(surname) ? 0 : 1),
        );
        if (match.isNotEmpty && !out.contains(match.first)) {
          out.add(match.first);
        }
      }
      return out;
  }
}

bool _eq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
