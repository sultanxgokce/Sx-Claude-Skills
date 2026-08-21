#!/usr/bin/env python3
"""
elogo-erisim · faturanın GÖRÜNÜM şablonu (XSLT) — ağsız, şirketsiz.

NİÇİN VAR (ölçüldü 2026-08-22, demo'ya gerçek gönderim)
-------------------------------------------------------
İlk gönderim denemesinde e-Logo şunu döndürdü:
    resultCode=-1 · "e-Belge görsel tasarım içermelidir."
İkinci denemede `UseDefaultXSLT=1` ile:
    resultCode=-1 · "Kayıtlı müşterinin tanımlı xslt bilgisine ulaşılamadı."

Yani UBL-TR faturası, belgenin insan gözüne NASIL görüneceğini tarif eden bir
XSLT taşımak zorunda. Üç yol var (arabirim dokümanı s.8); ikisi hesapta tanım
ister, üçüncüsü tanım İSTEMEZ:

    UseDefaultXSLT=1  → hesabın ön tanımlı tasarımı      (demo hesabında YOK)
    XSLTUUID=<uuid>   → portalden yüklenmiş tasarım       (demo hesabında YOK)
    gömülü            → tasarım BELGENİN İÇİNDE gelir     ← BU DOSYA

🔴 BU ŞABLON BİR TASARIM DEĞİL, BİR GEÇİŞ KAPISIDIR.
   Amacı güzel görünmek değil, belgenin **görüntülenebilir** olmasını sağlamak.
   Sade tutulmuştur: logo yok, renk yok, marka yok — çünkü marka kutu-yerel bir
   karardır ve bu dosya 16 kutunun ortak gördüğü rafta yaşar (İ1). Gerçek
   kurumsal tasarım portale yüklenir ve `XSLTUUID` ile çağrılır; o zaman bu
   şablon devreden çıkar.

🔴 ŞİRKETSİZ: firma adı, logo, adres, VKN GEÇMEZ. Şablon alanları faturanın
   kendisinden okur — yani ikinci bir tüzel kişide de aynı kalır.
"""
from __future__ import annotations

CBC = "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
CAC = "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
INV = "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"

#: Faturayı okunur bir HTML'e çeviren asgari şablon.
#: Değerlerin hepsi belgeden gelir; hiçbir sabit şirket bilgisi yoktur.
SABLON = f"""<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:inv="{INV}" xmlns:cac="{CAC}" xmlns:cbc="{CBC}">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>
  <xsl:template match="/inv:Invoice">
    <html><head><meta charset="UTF-8"/><title>e-Fatura</title>
    <style>
      body{{font-family:sans-serif;font-size:12px;color:#111;margin:24px}}
      h1{{font-size:16px;margin:0 0 12px}}
      table{{border-collapse:collapse;width:100%;margin-top:12px}}
      th,td{{border:1px solid #999;padding:5px;text-align:left}}
      th{{background:#eee}}
      .sag{{text-align:right}}
      .taraf{{display:inline-block;vertical-align:top;width:48%}}
    </style></head>
    <body>
      <h1>e-FATURA</h1>
      <div>
        <b>Belge No:</b> <xsl:value-of select="cbc:ID"/> ·
        <b>Tarih:</b> <xsl:value-of select="cbc:IssueDate"/> ·
        <b>Tür:</b> <xsl:value-of select="cbc:InvoiceTypeCode"/>
      </div>
      <xsl:for-each select="cbc:Note">
        <div><i><xsl:value-of select="."/></i></div>
      </xsl:for-each>

      <div style="margin-top:14px">
        <div class="taraf">
          <b>Düzenleyen</b><br/>
          <xsl:value-of select="cac:AccountingSupplierParty/cac:Party/cac:PartyName/cbc:Name"/><br/>
          <xsl:value-of select="cac:AccountingSupplierParty/cac:Party/cac:PartyIdentification/cbc:ID"/>
        </div>
        <div class="taraf">
          <b>Alıcı</b><br/>
          <xsl:value-of select="cac:AccountingCustomerParty/cac:Party/cac:PartyName/cbc:Name"/><br/>
          <xsl:value-of select="cac:AccountingCustomerParty/cac:Party/cac:PartyIdentification/cbc:ID"/>
        </div>
      </div>

      <table>
        <tr><th>#</th><th>Açıklama</th><th class="sag">Miktar</th>
            <th class="sag">Birim Fiyat</th><th class="sag">KDV %</th><th class="sag">Tutar</th></tr>
        <xsl:for-each select="cac:InvoiceLine">
          <tr>
            <td><xsl:value-of select="cbc:ID"/></td>
            <td><xsl:value-of select="cac:Item/cbc:Name"/></td>
            <td class="sag"><xsl:value-of select="cbc:InvoicedQuantity"/></td>
            <td class="sag"><xsl:value-of select="cac:Price/cbc:PriceAmount"/></td>
            <td class="sag"><xsl:value-of select="cac:TaxTotal/cac:TaxSubtotal/cbc:Percent"/></td>
            <td class="sag"><xsl:value-of select="cbc:LineExtensionAmount"/></td>
          </tr>
        </xsl:for-each>
      </table>

      <table style="margin-top:10px;width:40%;float:right">
        <tr><th>Matrah</th>
            <td class="sag"><xsl:value-of select="cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount"/></td></tr>
        <tr><th>KDV</th>
            <td class="sag"><xsl:value-of select="cac:TaxTotal/cbc:TaxAmount"/></td></tr>
        <tr><th>Genel Toplam</th>
            <td class="sag"><b><xsl:value-of select="cac:LegalMonetaryTotal/cbc:PayableAmount"/></b></td></tr>
      </table>
    </body></html>
  </xsl:template>
</xsl:stylesheet>
"""


def sablon_baytlari() -> bytes:
    """Şablonu UTF-8 baytları olarak döndürür (base64'ü çağıran alır)."""
    return SABLON.encode("utf-8")
