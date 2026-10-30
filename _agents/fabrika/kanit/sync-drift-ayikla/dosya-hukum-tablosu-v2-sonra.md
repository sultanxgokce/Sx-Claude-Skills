# sync-drift-ayikla — hüküm tablosu (BENNÂ · 30 Eki 2026)

Kaynak: `node sync-skills.mjs` kuru koşusu, Sx origin/main@7e5a5746 — 22 fark (21 içerik farkı + 1 kurulu kopya kaynaktan yeni).
Yöntem: her farklı dosya için kurulu kopyanın içeriği Sx git geçmişinde aranıp bulundu mu bakıldı (bulunduysa kurulu kopya
kaynağın ESKİ bir hâli), bulunmadıysa diff tek tek okundu.

(a) = kurulu kopyada değerli düzenleme var → kaynağa taşındı, sürüm artırıldı (bu PR; plan-dekor ve plan-motor hariç, aşağıya bak)
(b) = kurulu kopya eski ya da çöp → yalnız listelendi, ezme REİSTE (BÂNİ)

| beceri | hedef | hüküm | gerekçe | sürüm |
|---|---|---|---|---|
| whatsapp-gonder | _global | a | SKILL.md'de 403 `alici_bu_kutuya_kapali` teşhis tablosu + "etiket sır değildir" (İ1) bölümü; `scripts/wa-oku.sh` (gelen okuma istemcisi, cloudtop infra/wa-gecit/istemci kopyası — elle kopyalanmış, kaynakta yoktu) | 1.1.0→1.2.0 |
| railway-erisim | _global | a | `set-token`: klavye girişi olmayan kabukta (sohbetteki `!`) gizli giriş okunamaz → dürüst ret rc 2 | 1.1.0→1.1.1 |
| erisim-skill-fabrikasi | _global · nexus · cortex | b | kurulu kopyada `recipes/notion.md` YOK (kaynağa #192 ile eklendi); başka fark yok | — |
| notion-erisim | nexus | a | Nexus deposunda #1271: sınavda `printf … \| grep -q` → here-string (SIGPIPE 141 rastgele düşüşü) + sahte sunucuda kullanılmayan `sys` içe aktarımı | 1.0.0→1.0.1 |
| ahi | _global | b | kurulu DOCTRINE.md ve şema bir önceki sürüm; kaynakta 3 yeni dosya (katalog-surum-hiza, künye raporu) kurulu kopyada yok | — |
| kapimda | _global | a | A06-B: kapimda.md'ye ELLE yazılmış damgasız "Sultan onayladı" iddiasını lint yakalar (18 Eyl vakası); sınavın 8 kalemi kaynağın sınavına eklendi (kurulu sınav dosyasının geri kalanı ESKİ, alınmadı) | 1.7.0→1.8.0 |
| layiha-fabrikasi | _global | b | kurulu sınav dosyası kaynağın bir önceki sürümü | — |
| layiha-kapisi | _global | b | kurulu SKILL.md kaynağın bir önceki sürümü | — |
| sultan-alarmi | _global | a | `alarm.sh ders` 29 Eki dersini kurulu kopyadaki DERSLER.md'ye yazmış | 0.1.2→0.1.3 |
| plan-dekor | _global | a | kurulu kopyada geliştirme sürmüş: tema/mukarnas.json, lib/metin-olcu.mjs, katalog ve yerleşim değişiklikleri, kapı testi +300 satır (metrikler.jsonl çalışma verisi, alınmadı) — **bu PR'da DEĞİL**: taşıma `sync-drift-ayikla-plan` dalında hazır | (0.7.0) |
| plan-motor | _global | a | kurulu v1.6.0 > kaynak v1.4.0: katman/karışık katman/graf köprüsü, 10 yeni sınav (metrikler.jsonl ve node_modules alınmadı) — **bu PR'da DEĞİL**: taşıma `sync-drift-ayikla-plan` dalında hazır | (1.6.1) |
| kapi-sinavi | _global | a | `kayitsiz` komutu (sicile yazılmamış kapı), AST tabanlı yer-kaydırma mutasyonu, `bagli-mi` giriş dosyası yoksa ÖLÇÜLEMEDİ (ölü kod değil) + 12 yeni sınav kalemi (`_agents/beceri-anlik-goruntu` iç içe çöp, alınmadı) | 1.2.1→1.3.0 |
| olcum-disiplini | _global | a | `bicim` komutu (uzantı iddia, baytlar kanıt) + `kart --sayim` (.olcum/negatifler.jsonl çalışma verisi, alınmadı) | 1.0.0→1.1.0 |
| zeyl | _global · nexus · mmex · vekatip | b | kurulu sınav dosyası kaynağın bir önceki sürümü | — |
| durum-raporu | _global | a | `durum-yaz.sh --kaynak sultan\|eksik\|oneri` (Sultan 16 Eyl: iş satırı kaynağını söyler) + geçmiş 3→30 iş | 0.2.1→0.3.0 |
| terminal-onar | _global | b | yalnız iki `.bak-20261029` yedek dosyası fazla — çöp | — |
| hafta-kapanis | _global | b | kurulu sınav dosyası kaynağın eski bir sürümü | — |

plan-dekor + plan-motor neden ayrı: ikisinin farkı ~240 KB; bağımsız gözün istem tavanı 100 KB ("İŞİ BÖL"). Taşıma tamam ve
sınavları yerelde yeşil (plan-dekor kapi-testi + tests/kapi, plan-motor 11 sınav) — `sync-drift-ayikla-plan` dalında, PR açılmadı.
Bölme (daralt) reis kararıdır. O dalda ayrıca: CI paralel koştuğu için iki taşınan plan-motor sınavı npm bağımlılığını bulamıyordu
(yerelde ölçüldü: node_modules yokken rc 1) → kilitli ortak kurulum kapısı `plan-motor/tests/bagimlilik.sh`; eş zamanlı iki koşu yeşil.

Ölçüm (bu PR): drift-uyarı 22 → 14; kalan 14 = 12 (b) + plan-dekor + plan-motor. Duman 0 → 2: whatsapp-gonder (mimetype.test.sh) ve
kapi-sinavi (kapi-sinavi.sh, kapi-sinavi.test.sh) KURULU kopyalarında çalıştırma izni yok — kurulu kopyaların bugünkü hâli; kuru koşu
artık 'güncelle' dalında kurulu kopyayı da duman testinden geçirdiği için görünür oldu. Kaynakta üçü de 100755; reis kurunca düzelir.
