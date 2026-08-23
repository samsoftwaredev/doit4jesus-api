import type { LectionaryRepository } from '@/liturgy/lectionary/LectionaryRepository';
import type {
  LiturgicalCelebration,
  LiturgicalDay,
  ReadingSet,
} from '@/liturgy/models';
import { NabreScriptureRepository } from '@/liturgy/scripture/NabreScriptureRepository';

export interface LectionaryResolution {
  primary: ReadingSet | undefined;
  readingSets: ReadingSet[];
  celebration?: LiturgicalCelebration;
  sourceUrl?: string;
  lectionaryNumber?: string;
}

/**
 * Resolves data already selected by the calendar. It never determines the
 * celebration itself and never synthesizes a citation from arithmetic.
 */
export class LectionaryResolver {
  constructor(
    private readonly repository: LectionaryRepository,
    private readonly scriptureRepository = new NabreScriptureRepository(),
  ) {}

  resolve(day: LiturgicalDay): LectionaryResolution {
    const dateSpecific = this.repository.getDateSpecificReadings(
      day.date,
      day.country,
    );
    if (dateSpecific) {
      this.assertReferencesExist(dateSpecific.readingSets);
      return {
        primary: dateSpecific.readingSets[0],
        readingSets: dateSpecific.readingSets,
        celebration: dateSpecific.celebration,
        sourceUrl: dateSpecific.sourceUrl,
        lectionaryNumber: dateSpecific.lectionaryNumber,
      };
    }

    const proper = this.repository.getProperReadings(
      day.primaryCelebration.id,
      day.sundayCycle,
    );
    const temporal = this.repository.getTemporalReadings({
      season: day.season,
      week: day.week,
      weekday: day.weekday,
      sundayCycle: day.sundayCycle,
      weekdayCycle: day.weekdayCycle,
    });

    let readingSets: ReadingSet[];
    switch (day.primaryCelebration.readingSelectionRule) {
      case 'REQUIRED_PROPER':
        readingSets = proper?.readingSets ?? [];
        break;
      case 'OPTIONAL_PROPER':
        readingSets = [
          ...(temporal?.readingSets ?? []),
          ...(proper?.readingSets ?? []),
        ];
        break;
      case 'COMMON':
        readingSets = proper?.common
          ? this.repository
              .getCommonReadings(proper.common)
              .flatMap((entry) => entry.readingSets)
          : [];
        break;
      case 'MIXED':
        readingSets = [
          ...(proper?.readingSets ?? []),
          ...(temporal?.readingSets ?? []),
        ];
        break;
      case 'WEEKDAY':
      default:
        readingSets = temporal?.readingSets ?? [];
    }

    this.assertReferencesExist(readingSets);
    return { primary: readingSets[0], readingSets };
  }

  private assertReferencesExist(readingSets: ReadingSet[]) {
    for (const reading of readingSets.flatMap((set) => set.readings)) {
      if (!this.scriptureRepository.supportsCitation(reading.citation)) {
        throw new Error(
          `Lectionary citation is not supported by the local NABRE catalogue: ${reading.citation}`,
        );
      }
    }
  }
}
