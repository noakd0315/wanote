import { describe, expect, it } from 'vitest';
import {
  buildConsultationUserPrompt,
  parseConsultationRequestBody,
} from '../src/routes/consultation';

describe('parseConsultationRequestBody', () => {
  it('parses a minimal valid body with no referenced records', () => {
    const body = parseConsultationRequestBody({
      petId: 'pet-1',
      questionText: '今日はあまりご飯を食べません',
    });

    expect(body).toEqual({
      petId: 'pet-1',
      questionText: '今日はあまりご飯を食べません',
      referencedRecords: [],
    });
  });

  it('parses referencedRecords, filtering out non-string tags', () => {
    const body = parseConsultationRequestBody({
      petId: 'pet-1',
      questionText: '軟便が続いています',
      referencedRecords: [
        {
          recordId: 'rec-1',
          recordType: 'toiletRecord',
          label: '軟便 7/28',
          tags: ['軟便', 123, null, '継続'],
        },
      ],
    });

    expect(body.referencedRecords).toEqual([
      {
        recordId: 'rec-1',
        recordType: 'toiletRecord',
        label: '軟便 7/28',
        tags: ['軟便', '継続'],
      },
    ]);
  });

  it('throws when the body is not an object', () => {
    expect(() => parseConsultationRequestBody(null)).toThrow();
    expect(() => parseConsultationRequestBody('nope')).toThrow();
  });

  it('throws when petId is missing or empty', () => {
    expect(() => parseConsultationRequestBody({ questionText: 'x' })).toThrow('petId is required.');
    expect(() => parseConsultationRequestBody({ petId: '  ', questionText: 'x' })).toThrow(
      'petId is required.',
    );
  });

  it('throws when questionText is missing or empty', () => {
    expect(() => parseConsultationRequestBody({ petId: 'pet-1' })).toThrow(
      'questionText is required.',
    );
    expect(() => parseConsultationRequestBody({ petId: 'pet-1', questionText: '   ' })).toThrow(
      'questionText is required.',
    );
  });

  it('throws when questionText exceeds the length cap', () => {
    expect(() =>
      parseConsultationRequestBody({ petId: 'pet-1', questionText: 'x'.repeat(2001) }),
    ).toThrow('too long');
  });

  it('throws when referencedRecords is not an array', () => {
    expect(() =>
      parseConsultationRequestBody({ petId: 'pet-1', questionText: 'x', referencedRecords: 'nope' }),
    ).toThrow('referencedRecords must be an array.');
  });

  it('throws when a referencedRecords entry has the wrong shape', () => {
    expect(() =>
      parseConsultationRequestBody({
        petId: 'pet-1',
        questionText: 'x',
        referencedRecords: [{ recordId: 'rec-1' }],
      }),
    ).toThrow('Invalid referencedRecords entry shape.');
  });
});

describe('buildConsultationUserPrompt', () => {
  it('builds a prompt with just the question when there are no referenced records', () => {
    const prompt = buildConsultationUserPrompt({
      petId: 'pet-1',
      questionText: '今日はあまりご飯を食べません',
      referencedRecords: [],
    });

    expect(prompt).toBe('相談内容: 今日はあまりご飯を食べません');
  });

  it('appends referenced record context, including tags, when present', () => {
    const prompt = buildConsultationUserPrompt({
      petId: 'pet-1',
      questionText: '軟便が続いています',
      referencedRecords: [
        { recordId: 'rec-1', recordType: 'toiletRecord', label: '軟便 7/28', tags: ['軟便'] },
        { recordId: 'rec-2', recordType: 'weightRecord', label: '12.4kg (7/28)', tags: [] },
      ],
    });

    expect(prompt).toContain('相談内容: 軟便が続いています');
    expect(prompt).toContain('- [toiletRecord] 軟便 7/28（タグ: 軟便）');
    expect(prompt).toContain('- [weightRecord] 12.4kg (7/28)');
  });
});
