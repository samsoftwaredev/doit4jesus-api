export type ScriptureReference = {
  position: number;
  type: string;
  reference: string;
};

export type FeedReading = {
  readingDate: string;
  celebrationName: string;
  dailyReadingUrl: string;
  scriptureReferences: ScriptureReference[];
};

export type VerseRange = {
  startChapter: number;
  startVerse: number;
  endChapter: number;
  endVerse: number;
};

export type ParsedScriptureReference = {
  bookSlug: string;
  ranges: VerseRange[];
};

const MONTHS: Record<string, string> = {
  jan: '01',
  feb: '02',
  mar: '03',
  apr: '04',
  may: '05',
  jun: '06',
  jul: '07',
  aug: '08',
  sep: '09',
  oct: '10',
  nov: '11',
  dec: '12',
};

const BOOK_SLUGS: Record<string, string> = {
  genesis: 'genesis',
  exodus: 'exodus',
  leviticus: 'leviticus',
  numbers: 'numbers',
  deuteronomy: 'deuteronomy',
  joshua: 'josue',
  judges: 'judges',
  ruth: 'ruth',
  '1 samuel': '1-kings',
  '2 samuel': '2-kings',
  '1 kings': '3-kings',
  '2 kings': '4-kings',
  '1 chronicles': '1-paralipomenon',
  '2 chronicles': '2-paralipomenon',
  ezra: '1-esdras',
  nehemiah: '2-esdras',
  tobit: 'tobias',
  judith: 'judith',
  esther: 'esther',
  job: 'job',
  psalm: 'psalms',
  psalms: 'psalms',
  proverbs: 'proverbs',
  ecclesiastes: 'ecclesiastes',
  'song of songs': 'canticle-of-canticles',
  'song of solomon': 'canticle-of-canticles',
  wisdom: 'wisdom',
  sirach: 'ecclesiasticus',
  isaiah: 'isaie',
  jeremiah: 'jeremie',
  lamentations: 'lamentations',
  baruch: 'baruch',
  ezekiel: 'ezechiel',
  daniel: 'daniel',
  hosea: 'osee',
  joel: 'joel',
  amos: 'amos',
  obadiah: 'abdias',
  jonah: 'jonas',
  micah: 'micheas',
  nahum: 'nahum',
  habakkuk: 'habacuc',
  zephaniah: 'sophonias',
  haggai: 'aggeus',
  zechariah: 'zacharias',
  malachi: 'malachie',
  '1 maccabees': '1-machabees',
  '2 maccabees': '2-machabees',
  matthew: 'matthew',
  mark: 'mark',
  luke: 'luke',
  john: 'john',
  'acts of the apostles': 'acts',
  acts: 'acts',
  romans: 'romans',
  '1 corinthians': '1-corinthians',
  '2 corinthians': '2-corinthians',
  galatians: 'galatians',
  ephesians: 'ephesians',
  philippians: 'philippians',
  colossians: 'colossians',
  '1 thessalonians': '1-thessalonians',
  '2 thessalonians': '2-thessalonians',
  '1 timothy': '1-timothy',
  '2 timothy': '2-timothy',
  titus: 'titus',
  philemon: 'philemon',
  hebrews: 'hebrews',
  james: 'james',
  '1 peter': '1-peter',
  '2 peter': '2-peter',
  '1 john': '1-john',
  '2 john': '2-john',
  '3 john': '3-john',
  jude: 'jude',
  revelation: 'apocalypse',
};

function decodeEntities(value: string): string {
  return value
    .replace(/&#x([\da-f]+);/gi, (_, hexadecimal: string) =>
      String.fromCodePoint(Number.parseInt(hexadecimal, 16)),
    )
    .replace(/&#(\d+);/g, (_, decimal: string) =>
      String.fromCodePoint(Number.parseInt(decimal, 10)),
    )
    .replace(/&nbsp;/gi, ' ')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&amp;/gi, '&');
}

export function stripMarkup(value: string): string {
  return decodeEntities(value)
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]*>/g, '')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/[ \t]{2,}/g, ' ')
    .trim();
}

function extractElement(item: string, element: string): string | null {
  const match = item.match(new RegExp(`<${element}[^>]*>([\\s\\S]*?)</${element}>`, 'i'));
  return match ? decodeEntities(match[1].trim()) : null;
}

function parseReadingDate(pubDate: string): string | null {
  const match = pubDate.match(/(?:\w{3},\s+)?(\d{1,2})\s+(\w{3})\s+(\d{4})/);
  if (!match) return null;

  const month = MONTHS[match[2].toLowerCase()];
  if (!month) return null;

  return `${match[3]}-${month}-${match[1].padStart(2, '0')}`;
}

function toReadingType(label: string): string {
  const normalized = stripMarkup(label).toLowerCase();
  if (normalized.includes('responsorial psalm')) return 'psalm';
  if (normalized.includes('gospel')) return 'gospel';
  if (normalized.includes('alleluia') || normalized.includes('gospel acclamation')) {
    return 'acclamation';
  }
  if (normalized.includes('sequence')) return 'sequence';
  if (/reading\s*(ii|2)\b/.test(normalized)) return 'reading_2';
  if (normalized.includes('reading')) return 'reading_1';
  return 'reading';
}

function extractReferences(description: string): ScriptureReference[] {
  const references: ScriptureReference[] = [];
  const headingPattern = /<h4[^>]*>([\s\S]*?)<a\b[^>]*>([\s\S]*?)<\/a>[\s\S]*?<\/h4>/gi;
  let match: RegExpExecArray | null;

  while ((match = headingPattern.exec(description)) !== null) {
    const reference = stripMarkup(match[2]);
    if (!reference) continue;

    references.push({
      position: references.length + 1,
      type: toReadingType(match[1]),
      reference,
    });
  }

  return references;
}

export function parseDailyReadingsFeed(xml: string): FeedReading[] {
  const readings = new Map<string, FeedReading>();
  const itemPattern = /<item>([\s\S]*?)<\/item>/gi;
  let itemMatch: RegExpExecArray | null;

  while ((itemMatch = itemPattern.exec(xml)) !== null) {
    const item = itemMatch[1];
    const celebrationName = extractElement(item, 'title');
    const dailyReadingUrl = extractElement(item, 'link');
    const description = extractElement(item, 'description');
    const pubDate = extractElement(item, 'pubDate');

    if (!celebrationName || !dailyReadingUrl || !description || !pubDate) continue;

    const readingDate = parseReadingDate(pubDate);
    const scriptureReferences = extractReferences(description);
    if (!readingDate || scriptureReferences.length === 0) continue;

    readings.set(readingDate, {
      readingDate,
      celebrationName: stripMarkup(celebrationName),
      dailyReadingUrl,
      scriptureReferences,
    });
  }

  return [...readings.values()].sort((a, b) => a.readingDate.localeCompare(b.readingDate));
}

export function extractLectionaryNumber(pageHtml: string): number | null {
  const match = pageHtml.match(/Lectionary\s*:\s*(\d+)/i);
  return match ? Number.parseInt(match[1], 10) : null;
}

function normalizeBookName(value: string): string {
  return value
    .toLowerCase()
    .replace(/\./g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseVerseNumber(value: string): number | null {
  const match = value.match(/\d+/);
  return match ? Number.parseInt(match[0], 10) : null;
}

export function parseScriptureReference(
  reference: string,
): ParsedScriptureReference | null {
  const normalized = reference
    .replace(/^(?:see|cf\.?|compare)\s+/i, '')
    .replace(/[–—]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
  const match = normalized.match(/^(.*?)\s+(\d+)\s*:\s*(.+)$/);
  if (!match) return null;

  const bookSlug = BOOK_SLUGS[normalizeBookName(match[1])];
  const initialChapter = Number.parseInt(match[2], 10);
  if (!bookSlug || !Number.isInteger(initialChapter)) return null;

  const ranges: VerseRange[] = [];
  let activeChapter = initialChapter;

  for (const rawSegment of match[3].split(';')) {
    const segment = rawSegment.trim();
    if (!segment) continue;

    const chapterMatch = segment.match(/^(\d+)\s*:\s*(.+)$/);
    const verseList = chapterMatch ? chapterMatch[2] : segment;
    if (chapterMatch) activeChapter = Number.parseInt(chapterMatch[1], 10);

    for (const rawVerseRange of verseList.split(',')) {
      const compactRange = rawVerseRange.trim();
      if (!compactRange) continue;

      const rangeMatch = compactRange.match(
        /^(\d+[a-z]*)(?:\s*-\s*(?:(\d+)\s*:\s*)?(\d+[a-z]*))?$/i,
      );
      if (!rangeMatch) return null;

      const startVerse = parseVerseNumber(rangeMatch[1]);
      const endChapter = rangeMatch[2]
        ? Number.parseInt(rangeMatch[2], 10)
        : activeChapter;
      const endVerse = parseVerseNumber(rangeMatch[3] ?? rangeMatch[1]);
      if (!startVerse || !endVerse || endChapter < activeChapter) return null;

      ranges.push({
        startChapter: activeChapter,
        startVerse,
        endChapter,
        endVerse,
      });
    }
  }

  return ranges.length > 0 ? { bookSlug, ranges } : null;
}
