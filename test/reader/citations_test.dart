import 'package:flutter_test/flutter_test.dart';
import 'package:paper/features/reader/citations.dart';

void main() {
  group('findCitationMarkers', () {
    test('numeric markers with lists and ranges', () {
      const text = 'as shown in [12] and [3-5, 9] but not [a] or [].';
      final markers = findCitationMarkers(text);
      expect(markers.map((m) => m.raw), <String>['[12]', '[3-5, 9]']);
      expect(markers[0].numbers, <int>[12]);
      expect(markers[1].numbers, <int>[3, 4, 5, 9]);
      expect(markers[1].style, CitationStyle.numeric);
      expect(text.substring(markers[0].start, markers[0].end), '[12]');
    });

    test('en-dash ranges', () {
      expect(findCitationMarkers('see [1–3]').single.numbers, <int>[1, 2, 3]);
    });

    test('parenthetical author-year, single and multiple', () {
      const text =
          'Transformers (Vaswani et al., 2017) beat RNNs '
          '(Hochreiter & Schmidhuber, 1997; Cho et al. 2014a).';
      final markers = findCitationMarkers(text);
      expect(markers, hasLength(2));
      expect(markers[0].raw, '(Vaswani et al., 2017)');
      expect(markers[0].authorYears.single, (
        author: 'Vaswani et al.',
        year: '2017',
      ));
      expect(markers[1].authorYears.map((a) => a.year), <String>[
        '1997',
        '2014a',
      ]);
      expect(markers[1].authorYears.first.author, 'Hochreiter & Schmidhuber');
    });

    test('narrative citations include the author before the year', () {
      const text = 'as Smith and Jones (2020) argued';
      final m = findCitationMarkers(text).single;
      expect(m.raw, 'Smith and Jones (2020)');
      expect(m.authorYears.single.author, 'Smith and Jones');
      expect(m.authorYears.single.year, '2020');
    });

    test('ordinary parentheses are not citations', () {
      expect(
        findCitationMarkers('the loss (see Eq. 3) and (n = 2048)'),
        isEmpty,
      );
    });
  });

  test('citationMarkerAt finds the marker under a tapped char', () {
    const text = 'attention [7] is all';
    expect(citationMarkerAt(text, text.indexOf('7'))?.numbers, <int>[7]);
    expect(citationMarkerAt(text, text.indexOf('[')), isNotNull);
    expect(citationMarkerAt(text, 2), isNull);
    expect(citationMarkerAt(text, 999), isNull);
  });

  group('parseReferences', () {
    test('bracket-labelled list', () {
      final refs = parseReferences(<({int pageNumber, String text})>[
        (
          pageNumber: 9,
          text:
              'Conclusion text.\nReferences\n[1] A. Author. Paper one. 2019.\n',
        ),
        (
          pageNumber: 10,
          text: '[2] B. Writer. Paper two,\ncontinued. 2020.\n[3] C. Third. Three. 2021.',
        ),
      ]);
      expect(refs.map((r) => r.label), <String>['1', '2', '3']);
      expect(refs[1].text, 'B. Writer. Paper two, continued. 2020.');
      expect(refs[0].pageNumber, 9);
      expect(refs[1].pageNumber, 10);
    });

    test('dot-numbered list keeps only the 1, 2, 3… sequence', () {
      final refs = parseReferences(<({int pageNumber, String text})>[
        (
          pageNumber: 5,
          text: 'REFERENCES\n1. Alpha, A. First. 2018.\n2. Beta, B. Second.\n2019. Something\n3. Gamma, C. Third.',
        ),
      ]);
      expect(refs.map((r) => r.label), <String>['1', '2', '3']);
      expect(refs[1].text, contains('2019. Something'));
    });

    test('author-year list', () {
      final refs = parseReferences(<({int pageNumber, String text})>[
        (
          pageNumber: 12,
          text:
              'Bibliography\nHochreiter, S. and Schmidhuber, J. (1997). Long\nshort-term memory.\n'
              'Vaswani, A., Shazeer, N., et al. (2017). Attention is all you need.\n',
        ),
      ]);
      expect(refs, hasLength(2));
      expect(refs[0].text, startsWith('Hochreiter, S.'));
      expect(refs[1].text, startsWith('Vaswani, A.'));
    });

    test('appendix after the references ends the section', () {
      final refs = parseReferences(<({int pageNumber, String text})>[
        (
          pageNumber: 1,
          text: 'References\n[1] One.\n[2] Two.\nA Appendix\n[3] Not a reference.',
        ),
      ]);
      expect(refs.map((r) => r.label), <String>['1', '2']);
    });

    test('no heading -> empty', () {
      expect(
        parseReferences(<({int pageNumber, String text})>[
          (pageNumber: 1, text: '[1] looks like a list but no heading'),
        ]),
        isEmpty,
      );
    });
  });

  group('resolveCitation', () {
    final numeric = <ReferenceEntry>[
      const ReferenceEntry(label: '1', text: 'One.', pageNumber: 9),
      const ReferenceEntry(label: '2', text: 'Two.', pageNumber: 9),
      const ReferenceEntry(label: '3', text: 'Three.', pageNumber: 10),
    ];
    final authorYear = <ReferenceEntry>[
      const ReferenceEntry(
        text: 'Shazeer, N. (2017). Outrageously large networks.',
        pageNumber: 11,
      ),
      const ReferenceEntry(
        text: 'Vaswani, A., Shazeer, N., et al. (2017). Attention is all you need.',
        pageNumber: 12,
      ),
      const ReferenceEntry(text: 'Vaswani, A. (2019). Other.', pageNumber: 12),
    ];

    test('numeric markers resolve by label, in order', () {
      final m = findCitationMarkers('[3, 1]').single;
      expect(resolveCitation(m, numeric).map((r) => r.text), <String>[
        'Three.',
        'One.',
      ]);
      final missing = findCitationMarkers('[42]').single;
      expect(resolveCitation(missing, numeric), isEmpty);
    });

    test('author-year resolves by first-author surname + year', () {
      final m = findCitationMarkers('(Vaswani et al., 2017)').single;
      final r = resolveCitation(m, authorYear).single;
      expect(r.text, startsWith('Vaswani, A., Shazeer'));
      expect(r.pageNumber, 12);
    });
  });
}
