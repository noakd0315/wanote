import { describe, expect, it } from 'vitest';
import {
  buildReportUserPrompt,
  parseReportRequestBody,
  summarizeReportStats,
} from '../src/routes/report';

const validBody = {
  petId: 'pet-1',
  periodStart: '2026-07-01',
  periodEnd: '2026-07-31',
  weightSamples: [
    { date: '2026-07-01', weightKg: 10.2 },
    { date: '2026-07-31', weightKg: 10.8 },
  ],
  toiletCountsByDay: [
    { date: '2026-07-01', count: 3 },
    { date: '2026-07-02', count: 5 },
  ],
};

describe('parseReportRequestBody', () => {
  it('parses a fully valid body', () => {
    expect(parseReportRequestBody(validBody)).toEqual(validBody);
  });

  it('defaults weightSamples/toiletCountsByDay to empty arrays when omitted', () => {
    const body = parseReportRequestBody({
      petId: 'pet-1',
      periodStart: '2026-07-01',
      periodEnd: '2026-07-31',
    });
    expect(body.weightSamples).toEqual([]);
    expect(body.toiletCountsByDay).toEqual([]);
  });

  it('throws when petId is missing', () => {
    expect(() =>
      parseReportRequestBody({ periodStart: '2026-07-01', periodEnd: '2026-07-31' }),
    ).toThrow('petId is required.');
  });

  it('throws when period bounds are missing', () => {
    expect(() => parseReportRequestBody({ petId: 'pet-1' })).toThrow(
      'periodStart and periodEnd are required.',
    );
  });

  it('throws when a weightSamples entry has the wrong shape', () => {
    expect(() =>
      parseReportRequestBody({
        ...validBody,
        weightSamples: [{ date: '2026-07-01', weightKg: 'ten' }],
      }),
    ).toThrow('Invalid weightSamples entry shape.');
  });

  it('throws when a toiletCountsByDay entry has the wrong shape', () => {
    expect(() =>
      parseReportRequestBody({
        ...validBody,
        toiletCountsByDay: [{ date: '2026-07-01' }],
      }),
    ).toThrow('Invalid toiletCountsByDay entry shape.');
  });
});

describe('summarizeReportStats', () => {
  it('computes weight change from first to last sample', () => {
    const stats = summarizeReportStats(parseReportRequestBody(validBody));
    expect(stats.weightStartKg).toBe(10.2);
    expect(stats.weightEndKg).toBe(10.8);
    expect(stats.weightChangeKg).toBe(0.6);
  });

  it('sums and averages toilet counts per day', () => {
    const stats = summarizeReportStats(parseReportRequestBody(validBody));
    expect(stats.toiletTotalCount).toBe(8);
    expect(stats.toiletAveragePerDay).toBe(4);
  });

  it('reports nulls/zeros when there is no data for the period', () => {
    const stats = summarizeReportStats(
      parseReportRequestBody({ petId: 'pet-1', periodStart: '2026-07-01', periodEnd: '2026-07-31' }),
    );
    expect(stats.weightStartKg).toBeNull();
    expect(stats.weightEndKg).toBeNull();
    expect(stats.weightChangeKg).toBeNull();
    expect(stats.toiletTotalCount).toBe(0);
    expect(stats.toiletAveragePerDay).toBe(0);
  });

  it('rounds the weight change to one decimal place', () => {
    const stats = summarizeReportStats(
      parseReportRequestBody({
        ...validBody,
        weightSamples: [
          { date: '2026-07-01', weightKg: 10.23 },
          { date: '2026-07-31', weightKg: 10.876 },
        ],
      }),
    );
    expect(stats.weightChangeKg).toBe(0.6);
  });
});

describe('buildReportUserPrompt', () => {
  it('includes the period, weight change and toilet stats', () => {
    const prompt = buildReportUserPrompt(parseReportRequestBody(validBody));
    expect(prompt).toContain('対象期間: 2026-07-01 〜 2026-07-31');
    expect(prompt).toContain('体重推移: 10.2kg → 10.8kg（変化量: 0.6kg）');
    expect(prompt).toContain('トイレ記録: 合計8回（1日平均 4回）');
  });

  it('reports no weight data explicitly when there are no samples', () => {
    const prompt = buildReportUserPrompt(
      parseReportRequestBody({ petId: 'pet-1', periodStart: '2026-07-01', periodEnd: '2026-07-31' }),
    );
    expect(prompt).toContain('体重推移: この期間の体重記録はありません。');
  });
});
