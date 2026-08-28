import { randomBytes } from 'node:crypto';

import { evaluateUsername } from '@/lib/usernames/moderation';

const SAINTS = [
  'benedict',
  'cecilia',
  'clare',
  'dominic',
  'francis',
  'joseph',
  'kateri',
  'kolbe',
  'monica',
  'patrick',
  'paul',
  'therese',
  'teresa',
] as const;

const VIRTUES = [
  'brave',
  'faithful',
  'gracious',
  'hopeful',
  'humble',
  'joyful',
  'merciful',
  'peaceful',
  'prayerful',
  'steadfast',
] as const;

const SYMBOLS = [
  'disciple',
  'dove',
  'fisher',
  'gospel',
  'lantern',
  'lily',
  'pilgrim',
  'psalmist',
  'rosary',
  'servant',
  'shepherd',
  'witness',
] as const;

type SuggestionOptions = {
  count?: number;
  now?: number;
  entropy?: number;
};

function createRandom(seed: number) {
  let state = seed >>> 0 || 0x6d2b79f5;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return (state >>> 0) / 0x1_0000_0000;
  };
}

function pick<T>(values: readonly T[], random: () => number) {
  return values[Math.floor(random() * values.length)];
}

export function generateUsernameCandidates({
  count = 60,
  now = Date.now(),
  entropy = randomBytes(4).readUInt32LE(0),
}: SuggestionOptions = {}) {
  const random = createRandom((now & 0xffff_ffff) ^ entropy);
  const timeCode = Math.floor(now / 1_000) % 10_000;
  const candidates = new Set<string>();

  for (
    let attempt = 0;
    candidates.size < count && attempt < count * 20;
    attempt += 1
  ) {
    const suffix = String(
      (timeCode + Math.floor(random() * 10_000)) % 10_000,
    ).padStart(4, '0');
    const pattern = attempt % 3;
    const candidate =
      pattern === 0
        ? `${pick(VIRTUES, random)}_${pick(SAINTS, random)}${suffix}`
        : pattern === 1
          ? `${pick(SAINTS, random)}_${pick(SYMBOLS, random)}${suffix}`
          : `${pick(VIRTUES, random)}_${pick(SYMBOLS, random)}${suffix}`;

    if (evaluateUsername(candidate).valid) candidates.add(candidate);
  }

  return [...candidates];
}
