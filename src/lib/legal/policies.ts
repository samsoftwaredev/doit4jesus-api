export const LEGAL_POLICY_VERSIONS = {
  terms: '2026-10-28',
  privacy: '2026-10-28',
  communityGuidelines: '2026-10-28',
} as const;

export const LEGAL_ACCEPTANCE_CUTOFF = '2026-10-27T05:00:00.000Z';

export type LegalAcceptanceStatus = {
  required: boolean;
  accepted: boolean;
  grandfathered: boolean;
  termsVersion: string;
  privacyVersion: string;
  communityGuidelinesVersion: string;
  acceptedAt: string | null;
};

export function toLegalAcceptanceStatus(
  accountCreatedAt: string,
  acceptedAt: string | null,
): LegalAcceptanceStatus {
  const grandfathered =
    new Date(accountCreatedAt).getTime() <
    new Date(LEGAL_ACCEPTANCE_CUTOFF).getTime();
  const accepted = acceptedAt !== null;

  return {
    required: !grandfathered && !accepted,
    accepted,
    grandfathered,
    termsVersion: LEGAL_POLICY_VERSIONS.terms,
    privacyVersion: LEGAL_POLICY_VERSIONS.privacy,
    communityGuidelinesVersion: LEGAL_POLICY_VERSIONS.communityGuidelines,
    acceptedAt,
  };
}
