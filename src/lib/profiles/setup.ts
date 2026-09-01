export const REQUIRED_PROFILE_FIELDS = [
  'displayName',
  'gender',
  'country',
] as const;

export type RequiredProfileField = (typeof REQUIRED_PROFILE_FIELDS)[number];
export type ProfileSetupStep = 'name' | 'gender' | 'country';

type ProfileSetupValues = {
  displayName: string | null;
  gender: 'male' | 'female' | null;
  countryCode: string | null;
  countryExists?: boolean;
  completedAt: string | null;
};

const stepByField: Record<RequiredProfileField, ProfileSetupStep> = {
  displayName: 'name',
  gender: 'gender',
  country: 'country',
};

export function getProfileSetup(values: ProfileSetupValues) {
  const missingFields: RequiredProfileField[] = [];

  if (!values.displayName?.trim()) missingFields.push('displayName');
  if (values.gender !== 'male' && values.gender !== 'female') {
    missingFields.push('gender');
  }
  if (!values.countryCode?.trim() || values.countryExists === false) {
    missingFields.push('country');
  }

  return {
    complete: missingFields.length === 0,
    missingFields,
    nextStep: missingFields[0] ? stepByField[missingFields[0]] : null,
    completedAt: values.completedAt,
  };
}
