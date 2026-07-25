import {
  extractLectionaryNumber,
  parseDailyReadingsFeed,
  parseScriptureReference,
} from './daily-readings';

describe('daily-reading feed parser', () => {
  it('retains only the date, celebration, and Scripture references from an RSS item', () => {
    const readings = parseDailyReadingsFeed(`
      <rss><channel><item>
        <title>Feast of Saint James, Apostle</title>
        <link>https://example.test/readings/072526.cfm</link>
        <description>
          &lt;h4&gt;Reading 1 &lt;a href="https://example.test/2corinthians/4"&gt;2 Corinthians 4:7-15&lt;/a&gt;&lt;/h4&gt;
          &lt;p&gt;This text is intentionally not parsed or retained.&lt;/p&gt;
          &lt;h4&gt;Responsorial Psalm &lt;a href="https://example.test/psalms/126"&gt;Psalm 126:1bc-2ab, 2cd-3, 4-5, 6&lt;/a&gt;&lt;/h4&gt;
          &lt;h4&gt;Gospel &lt;a href="https://example.test/matthew/20"&gt;Matthew 20:20-28&lt;/a&gt;&lt;/h4&gt;
        </description>
        <pubDate>Sat, 25 Jul 2026 04:30:00 EDT</pubDate>
      </item></channel></rss>
    `);

    expect(readings).toEqual([
      {
        readingDate: '2026-07-25',
        celebrationName: 'Feast of Saint James, Apostle',
        dailyReadingUrl: 'https://example.test/readings/072526.cfm',
        scriptureReferences: [
          { position: 1, type: 'reading_1', reference: '2 Corinthians 4:7-15' },
          {
            position: 2,
            type: 'psalm',
            reference: 'Psalm 126:1bc-2ab, 2cd-3, 4-5, 6',
          },
          { position: 3, type: 'gospel', reference: 'Matthew 20:20-28' },
        ],
      },
    ]);
  });

  it('reads the lectionary number from the daily page without retaining the page', () => {
    expect(extractLectionaryNumber('<p>Lectionary: 615</p>')).toBe(615);
  });
});

describe('Scripture reference parser', () => {
  it('maps modern book names and partial Psalm verses to the Bible API format', () => {
    expect(parseScriptureReference('Psalm 126:1bc-2ab, 2cd-3, 4-5, 6')).toEqual({
      bookSlug: 'psalms',
      ranges: [
        { startChapter: 126, startVerse: 1, endChapter: 126, endVerse: 2 },
        { startChapter: 126, startVerse: 2, endChapter: 126, endVerse: 3 },
        { startChapter: 126, startVerse: 4, endChapter: 126, endVerse: 5 },
        { startChapter: 126, startVerse: 6, endChapter: 126, endVerse: 6 },
      ],
    });
  });

  it('supports a prefixed acclamation reference', () => {
    expect(parseScriptureReference('See John 15:16')).toEqual({
      bookSlug: 'john',
      ranges: [
        { startChapter: 15, startVerse: 16, endChapter: 15, endVerse: 16 },
      ],
    });
  });
});
