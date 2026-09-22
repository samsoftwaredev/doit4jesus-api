#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { basename, resolve } from 'node:path';

const OUTPUT_DIRECTORY = resolve('src/data/bible/es');
const EXPECTED_SHA256 =
  '78eaa9d2998f73c59904fe59d88ac8b658a56fadccea98463bb7ffa73646e834';

const books = [
  ['Génesis', 'Genesis', 'Génesis'],
  ['Exodo', 'Exodus', 'Éxodo'],
  ['Levítico', 'Leviticus', 'Levítico'],
  ['Números', 'Numbers', 'Números'],
  ['Deuteronomio', 'Deuteronomy', 'Deuteronomio'],
  ['Josué', 'Joshua', 'Josué'],
  ['Jueces', 'Judges', 'Jueces'],
  ['Rut', 'Ruth', 'Rut'],
  ['I Samuel', '1Samuel', '1 Samuel'],
  ['II Samuel', '2Samuel', '2 Samuel'],
  ['I Reyes', '1Kings', '1 Reyes'],
  ['II Reyes', '2Kings', '2 Reyes'],
  [' I Crónicas', '1Chronicles', '1 Crónicas'],
  ['II Crónicas', '2Chronicles', '2 Crónicas'],
  ['Esdras', 'Ezra', 'Esdras'],
  ['Nehemías', 'Nehemiah', 'Nehemías'],
  ['Tobías', 'Tobit', 'Tobías'],
  ['Judit', 'Judith', 'Judit'],
  ['Ester', 'Esther', 'Ester'],
  ['I Macabeos', '1Maccabees', '1 Macabeos'],
  ['II Macabeos', '2Maccabees', '2 Macabeos'],
  ['Job', 'Job', 'Job'],
  ['Salmos', 'Psalms', 'Salmos'],
  ['Proverbios', 'Proverbs', 'Proverbios'],
  ['Eclesiastés', 'Ecclesiastes', 'Eclesiastés'],
  ['Cantar', 'SongofSongs', 'Cantar de los Cantares'],
  ['Sabiduría', 'Wisdom', 'Sabiduría'],
  ['Eclesiástico', 'Sirach', 'Eclesiástico'],
  ['Isaías', 'Isaiah', 'Isaías'],
  ['Jeremías', 'Jeremiah', 'Jeremías'],
  ['Lamentaciones', 'Lamentations', 'Lamentaciones'],
  ['Baruc', 'Baruch', 'Baruc'],
  ['Ezequiel', 'Ezekiel', 'Ezequiel'],
  ['Daniel', 'Daniel', 'Daniel'],
  ['Oseas', 'Hosea', 'Oseas'],
  ['Joel', 'Joel', 'Joel'],
  ['Amós', 'Amos', 'Amós'],
  ['Abdías', 'Obadiah', 'Abdías'],
  ['Jonás', 'Jonah', 'Jonás'],
  ['Miqueas', 'Micah', 'Miqueas'],
  ['Nahún', 'Nahum', 'Nahúm'],
  ['Habacuc', 'Habakkuk', 'Habacuc'],
  ['Sofonías', 'Zephaniah', 'Sofonías'],
  ['Ageo', 'Haggai', 'Ageo'],
  ['Zacarías', 'Zechariah', 'Zacarías'],
  ['Malaquías', 'Malachi', 'Malaquías'],
  [' Mateo', 'Matthew', 'Mateo'],
  ['Marcos', 'Mark', 'Marcos'],
  ['Lucas', 'Luke', 'Lucas'],
  ['Juan', 'John', 'Juan'],
  ['Hechos', 'Acts', 'Hechos'],
  ['Romanos', 'Romans', 'Romanos'],
  ['I Corintios', '1Corinthians', '1 Corintios'],
  ['II Corintios', '2Corinthians', '2 Corintios'],
  ['Gálatas', 'Galatians', 'Gálatas'],
  ['Efesios', 'Ephesians', 'Efesios'],
  ['Filipenses', 'Philippians', 'Filipenses'],
  ['Colosenses', 'Colossians', 'Colosenses'],
  ['I Tesalonicenses', '1Thessalonians', '1 Tesalonicenses'],
  ['II Tesalonicenses', '2Thessalonians', '2 Tesalonicenses'],
  ['I Timoteo', '1Timothy', '1 Timoteo'],
  ['II Timoteo', '2Timothy', '2 Timoteo'],
  ['Tito', 'Titus', 'Tito'],
  ['Filemon', 'Philemon', 'Filemón'],
  ['Hebreos', 'Hebrews', 'Hebreos'],
  ['Santiago', 'James', 'Santiago'],
  ['I Pedro', '1Peter', '1 Pedro'],
  ['II Pedro', '2Peter', '2 Pedro'],
  ['I Juan', '1John', '1 Juan'],
  ['II Juan', '2John', '2 Juan'],
  ['III Juan', '3John', '3 Juan'],
  ['Judas', 'Jude', 'Judas'],
  ['Apocalipsis', 'Revelation', 'Apocalipsis'],
];

function argument(name) {
  return process.argv
    .find((value) => value.startsWith(`--${name}=`))
    ?.slice(name.length + 3);
}

function json(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

function convertBook(sourceBook, displayName) {
  if (!Array.isArray(sourceBook.chapters)) {
    throw new Error(`Missing chapters for ${displayName}.`);
  }

  return {
    book: displayName,
    chapters: sourceBook.chapters.map((chapter) => ({
      chapter: Number.parseInt(chapter.chapter, 10),
      verses: Object.entries(chapter.verses).map(([verse, text]) => ({
        verse: Number.parseInt(verse, 10),
        text,
      })),
    })),
  };
}

async function main() {
  const inputArgument = argument('input');
  if (!inputArgument) {
    throw new Error(
      'Pass the BibliAPI db/biblia.json path as --input=/absolute/or/relative/path.',
    );
  }

  const inputPath = resolve(inputArgument);
  const input = await readFile(inputPath);
  const checksum = createHash('sha256').update(input).digest('hex');
  if (checksum !== EXPECTED_SHA256) {
    throw new Error(
      `${basename(inputPath)} does not match the pinned BibliAPI snapshot. ` +
        `Expected ${EXPECTED_SHA256}, received ${checksum}.`,
    );
  }

  const source = JSON.parse(input.toString('utf8'));
  const converted = books.map(([sourceName, canonicalName, displayName]) => {
    const sourceBook = source[sourceName];
    if (!sourceBook) throw new Error(`Missing source book ${sourceName}.`);
    return {
      canonicalName,
      value: convertBook(sourceBook, displayName),
    };
  });

  if (
    Object.keys(source).length !== books.length ||
    converted.length !== books.length
  ) {
    throw new Error('The source must contain exactly the expected 73 books.');
  }

  await mkdir(resolve(OUTPUT_DIRECTORY, 'books'), { recursive: true });
  await Promise.all(
    converted.map(({ canonicalName, value }) =>
      writeFile(
        resolve(OUTPUT_DIRECTORY, 'books', `${canonicalName}.json`),
        json(value),
      ),
    ),
  );

  await Promise.all([
    writeFile(
      resolve(OUTPUT_DIRECTORY, 'bible-all-books.json'),
      json(converted.map(({ value }) => value.book)),
    ),
    writeFile(
      resolve(OUTPUT_DIRECTORY, 'bible-biblia-de-jerusalen-book-chapters.json'),
      json(
        converted.map(({ value }) => ({
          Book: value.book,
          Chapters: value.chapters.length,
        })),
      ),
    ),
    writeFile(
      resolve(OUTPUT_DIRECTORY, 'biblia-de-jerusalen.json'),
      json(converted.map(({ value }) => value)),
    ),
  ]);

  console.log(`Imported ${converted.length} Spanish Bible books.`);
}

await main();
