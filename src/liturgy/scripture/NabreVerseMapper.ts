import type { ScriptureReading } from '@/liturgy/models';
import { canonicalBookForCitation } from '@/liturgy/scripture/NabreScriptureRepository';

type BibleVerse = { verse: number; text: string };
type BibleChapter = { chapter: number; verses: BibleVerse[] };
type BibleBook = { book: string; chapters: BibleChapter[] };
type BookLoader = () => Promise<{ default: BibleBook }>;
type VerseRange = {
  startChapter: number;
  startVerse: number;
  endChapter: number;
  endVerse: number;
};

const singleChapterBooks = new Set([
  'Obadiah',
  'Philemon',
  'Jude',
  '2John',
  '3John',
]);

export class NabreVerseMappingError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NabreVerseMappingError';
  }
}

/**
 * Keep one lazy loader per source file. This lets Next trace the local book
 * assets while avoiding a 6.8 MB all-Bible import for every Mass-readings call.
 */
const bookLoaders: Record<string, BookLoader> = {
  '1Chronicles': () => import('@/data/bible/books/1Chronicles.json'),
  '1Corinthians': () => import('@/data/bible/books/1Corinthians.json'),
  '1John': () => import('@/data/bible/books/1John.json'),
  '1Kings': () => import('@/data/bible/books/1Kings.json'),
  '1Maccabees': () => import('@/data/bible/books/1Maccabees.json'),
  '1Peter': () => import('@/data/bible/books/1Peter.json'),
  '1Samuel': () => import('@/data/bible/books/1Samuel.json'),
  '1Thessalonians': () => import('@/data/bible/books/1Thessalonians.json'),
  '1Timothy': () => import('@/data/bible/books/1Timothy.json'),
  '2Chronicles': () => import('@/data/bible/books/2Chronicles.json'),
  '2Corinthians': () => import('@/data/bible/books/2Corinthians.json'),
  '2John': () => import('@/data/bible/books/2John.json'),
  '2Kings': () => import('@/data/bible/books/2Kings.json'),
  '2Maccabees': () => import('@/data/bible/books/2Maccabees.json'),
  '2Peter': () => import('@/data/bible/books/2Peter.json'),
  '2Samuel': () => import('@/data/bible/books/2Samuel.json'),
  '2Thessalonians': () => import('@/data/bible/books/2Thessalonians.json'),
  '2Timothy': () => import('@/data/bible/books/2Timothy.json'),
  '3John': () => import('@/data/bible/books/3John.json'),
  Acts: () => import('@/data/bible/books/Acts.json'),
  Amos: () => import('@/data/bible/books/Amos.json'),
  Baruch: () => import('@/data/bible/books/Baruch.json'),
  Colossians: () => import('@/data/bible/books/Colossians.json'),
  Daniel: () => import('@/data/bible/books/Daniel.json'),
  Deuteronomy: () => import('@/data/bible/books/Deuteronomy.json'),
  Ecclesiastes: () => import('@/data/bible/books/Ecclesiastes.json'),
  Ephesians: () => import('@/data/bible/books/Ephesians.json'),
  Esther: () => import('@/data/bible/books/Esther.json'),
  Exodus: () => import('@/data/bible/books/Exodus.json'),
  Ezekiel: () => import('@/data/bible/books/Ezekiel.json'),
  Ezra: () => import('@/data/bible/books/Ezra.json'),
  Galatians: () => import('@/data/bible/books/Galatians.json'),
  Genesis: () => import('@/data/bible/books/Genesis.json'),
  Habakkuk: () => import('@/data/bible/books/Habakkuk.json'),
  Haggai: () => import('@/data/bible/books/Haggai.json'),
  Hebrews: () => import('@/data/bible/books/Hebrews.json'),
  Hosea: () => import('@/data/bible/books/Hosea.json'),
  Isaiah: () => import('@/data/bible/books/Isaiah.json'),
  James: () => import('@/data/bible/books/James.json'),
  Jeremiah: () => import('@/data/bible/books/Jeremiah.json'),
  Job: () => import('@/data/bible/books/Job.json'),
  Joel: () => import('@/data/bible/books/Joel.json'),
  John: () => import('@/data/bible/books/John.json'),
  Jonah: () => import('@/data/bible/books/Jonah.json'),
  Joshua: () => import('@/data/bible/books/Joshua.json'),
  Jude: () => import('@/data/bible/books/Jude.json'),
  Judges: () => import('@/data/bible/books/Judges.json'),
  Judith: () => import('@/data/bible/books/Judith.json'),
  Lamentations: () => import('@/data/bible/books/Lamentations.json'),
  Leviticus: () => import('@/data/bible/books/Leviticus.json'),
  Luke: () => import('@/data/bible/books/Luke.json'),
  Malachi: () => import('@/data/bible/books/Malachi.json'),
  Mark: () => import('@/data/bible/books/Mark.json'),
  Matthew: () => import('@/data/bible/books/Matthew.json'),
  Micah: () => import('@/data/bible/books/Micah.json'),
  Nahum: () => import('@/data/bible/books/Nahum.json'),
  Nehemiah: () => import('@/data/bible/books/Nehemiah.json'),
  Numbers: () => import('@/data/bible/books/Numbers.json'),
  Obadiah: () => import('@/data/bible/books/Obadiah.json'),
  Philemon: () => import('@/data/bible/books/Philemon.json'),
  Philippians: () => import('@/data/bible/books/Philippians.json'),
  Proverbs: () => import('@/data/bible/books/Proverbs.json'),
  Psalms: () => import('@/data/bible/books/Psalms.json'),
  Revelation: () => import('@/data/bible/books/Revelation.json'),
  Romans: () => import('@/data/bible/books/Romans.json'),
  Ruth: () => import('@/data/bible/books/Ruth.json'),
  Sirach: () => import('@/data/bible/books/Sirach.json'),
  SongofSongs: () => import('@/data/bible/books/SongofSongs.json'),
  Titus: () => import('@/data/bible/books/Titus.json'),
  Tobit: () => import('@/data/bible/books/Tobit.json'),
  Wisdom: () => import('@/data/bible/books/Wisdom.json'),
  Zechariah: () => import('@/data/bible/books/Zechariah.json'),
  Zephaniah: () => import('@/data/bible/books/Zephaniah.json'),
};

function parseVerseNumber(value: string) {
  const match = value.match(/^\d+/);
  return match ? Number.parseInt(match[0], 10) : null;
}

function parseRanges(citation: string): { book: string; ranges: VerseRange[] } {
  // USCCB calendar entries occasionally annotate an otherwise valid citation,
  // for example "(second choice)". The note is not part of the reference.
  const normalizedCitation = citation
    .trim()
    .replace(/\s+\((?!\d)[^)]+\)\s*$/, '');
  const match = normalizedCitation
    .trim()
    .match(/^((?:[1-3]\s*)?[A-Za-z]+(?:\s+[A-Za-z]+)*)\s+(\d.+)$/);
  const book = canonicalBookForCitation(normalizedCitation);
  if (!match || !book) {
    throw new NabreVerseMappingError(`Unsupported NABRE citation: ${citation}`);
  }

  let activeChapter: number | null = null;
  const ranges: VerseRange[] = [];
  const references = match[2]
    .replace(/[–—]/g, '-')
    .replace(/\band\b/gi, ',')
    .split(';');

  for (const reference of references) {
    const chapterMatch = reference.trim().match(/^(\d+)\s*:\s*(.+)$/);
    const verseExpression = chapterMatch?.[2] ?? reference.trim();
    if (!chapterMatch && !singleChapterBooks.has(book)) {
      throw new NabreVerseMappingError(
        `Unsupported NABRE citation segment: ${citation}`,
      );
    }
    activeChapter = chapterMatch ? Number.parseInt(chapterMatch[1], 10) : 1;

    for (const rawRange of verseExpression.split(',')) {
      const range = rawRange.trim();
      if (!range) continue;
      const rangeMatch = range.match(
        /^(\d+[a-z]*)(?:\s*-\s*(?:(\d+)\s*:\s*)?(\d+[a-z]*))?$/i,
      );
      if (!rangeMatch || activeChapter === null) {
        throw new NabreVerseMappingError(
          `Unsupported NABRE verse range: ${citation}`,
        );
      }

      const startVerse = parseVerseNumber(rangeMatch[1]);
      const endChapter = rangeMatch[2]
        ? Number.parseInt(rangeMatch[2], 10)
        : activeChapter;
      const endVerse = parseVerseNumber(rangeMatch[3] ?? rangeMatch[1]);
      if (!startVerse || !endVerse || endChapter < activeChapter) {
        throw new NabreVerseMappingError(
          `Invalid NABRE verse range: ${citation}`,
        );
      }
      ranges.push({
        startChapter: activeChapter,
        startVerse,
        endChapter,
        endVerse,
      });
    }
  }

  return { book, ranges };
}

export class NabreVerseMapper {
  private readonly cache = new Map<string, BibleBook>();

  async mapReading(reading: ScriptureReading): Promise<ScriptureReading> {
    const { book, ranges } = parseRanges(reading.citation);
    const bibleBook = await this.getBook(book);
    const verses = this.selectVerses(bibleBook, ranges, reading.citation);

    return {
      ...reading,
      text: verses
        .map(
          (verse) =>
            `${bibleBook.book} ${verse.chapter}:${verse.verse} ${verse.text}`,
        )
        .join('\n'),
    };
  }

  async mapReadings(readings: ScriptureReading[]) {
    return Promise.all(
      readings.map(async (reading) => {
        try {
          return await this.mapReading(reading);
        } catch (error) {
          // A reference remains useful even if the currently checked-in NABRE
          // book file has not yet supplied those verses. Do not turn a valid
          // USCCB lectionary result into a server error or fabricate text.
          if (error instanceof NabreVerseMappingError) return reading;
          throw error;
        }
      }),
    );
  }

  private async getBook(book: string) {
    const cached = this.cache.get(book);
    if (cached) return cached;

    const loader = bookLoaders[book];
    if (!loader)
      throw new NabreVerseMappingError(
        `No local NABRE book file exists for ${book}.`,
      );
    const loaded = await loader();
    this.cache.set(book, loaded.default);
    return loaded.default;
  }

  private selectVerses(
    book: BibleBook,
    ranges: VerseRange[],
    citation: string,
  ) {
    const selected: Array<{ chapter: number; verse: number; text: string }> =
      [];
    const seen = new Set<string>();

    for (const range of ranges) {
      for (
        let chapterNumber = range.startChapter;
        chapterNumber <= range.endChapter;
        chapterNumber += 1
      ) {
        const chapter = book.chapters.find(
          (candidate) => candidate.chapter === chapterNumber,
        );
        if (!chapter) {
          throw new NabreVerseMappingError(
            `Chapter ${chapterNumber} is unavailable for ${citation}.`,
          );
        }
        const firstVerse =
          chapterNumber === range.startChapter ? range.startVerse : 1;
        const lastVerse =
          chapterNumber === range.endChapter ? range.endVerse : Infinity;
        for (const verse of chapter.verses) {
          if (verse.verse < firstVerse || verse.verse > lastVerse) continue;
          const key = `${chapterNumber}:${verse.verse}`;
          if (seen.has(key)) continue;
          seen.add(key);
          selected.push({
            chapter: chapterNumber,
            verse: verse.verse,
            text: verse.text,
          });
        }
      }
    }

    if (selected.length === 0) {
      throw new NabreVerseMappingError(
        `No local NABRE verses matched ${citation}.`,
      );
    }
    return selected;
  }
}
