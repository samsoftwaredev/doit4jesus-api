import { createContactRequestSchema } from '../src/lib/schemas/contact'

describe('createContactRequestSchema', () => {
  it('accepts an Other subject with a user-specified label', () => {
    expect(
      createContactRequestSchema.parse({
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        subject: 'Other',
        otherSubject: 'Accessibility question',
        message: 'Can you improve voice-over support?',
      }),
    ).toEqual({
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      subject: 'Other',
      otherSubject: 'Accessibility question',
      message: 'Can you improve voice-over support?',
    })
  })

  it('rejects a custom subject for a listed category', () => {
    expect(() =>
      createContactRequestSchema.parse({
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        subject: 'Billing & Payments',
        otherSubject: 'Different billing issue',
        message: 'Please send my receipt.',
      }),
    ).toThrow('otherSubject may only be provided when subject is Other.')
  })
})
