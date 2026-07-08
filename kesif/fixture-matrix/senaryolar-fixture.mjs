// senaryolar-fixture.mjs — MMEx-DIŞI generic-fixture senaryo-config'i (portability kanıtı).
// apiEndpoints/readySelector MMEx'ten TAMAMEN FARKLI → aynı generic-runner (e2e-run.mjs) config-swap ile koşar.
import { bekle } from '../scripts/kesif_lib.mjs';

export const apiEndpoints = { data: '/fixture/data' }; // MMEx: /api/sources/health... ; burada: /fixture/data
export const readySelector = '[data-testid="widget"]'; // MMEx: [data-testid="sources-list"]

export const senaryolar = [
  {
    ad: 'fixture-render-bagi',
    aciklama: 'widget data-value == API /fixture/data value (DOM↔API çapraz-kanıt, generic-core endpoint-bilmez)',
    async calistir(page, api) {
      const dom = await page.locator('[data-testid="widget"]').getAttribute('data-value');
      return bekle(Number(dom) === api.data.value, `dom=${dom} api=${api.data.value}`);
    },
  },
];
