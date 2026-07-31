package com.example.flutter_receipt_scanner_android

import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test

class OcrScriptResolverTest {
    @Before
    fun setup() {
        mockkStatic(android.icu.util.ULocale::class)
        val mockKo = mockk<android.icu.util.ULocale>()
        every { mockKo.language } returns "ko"
        every { mockKo.script } returns "Kore"

        val mockEn = mockk<android.icu.util.ULocale>()
        every { mockEn.language } returns "en"
        every { mockEn.script } returns "Latn"

        val mockJa = mockk<android.icu.util.ULocale>()
        every { mockJa.language } returns "ja"
        every { mockJa.script } returns "Jpan"

        val mockFr = mockk<android.icu.util.ULocale>()
        every { mockFr.language } returns "fr"
        every { mockFr.script } returns "Latn"

        val mockDe = mockk<android.icu.util.ULocale>()
        every { mockDe.language } returns "de"
        every { mockDe.script } returns "Latn"

        val mockPrivate = mockk<android.icu.util.ULocale>()
        every { mockPrivate.language } returns ""
        every { mockPrivate.script } returns ""

        val mockTagKo = mockk<android.icu.util.ULocale>()
        val mockTagEn = mockk<android.icu.util.ULocale>()
        val mockTagJa = mockk<android.icu.util.ULocale>()
        val mockTagFr = mockk<android.icu.util.ULocale>()
        val mockTagDe = mockk<android.icu.util.ULocale>()
        val mockTagPrivate = mockk<android.icu.util.ULocale>()

        every {
            android.icu.util.ULocale
                .forLanguageTag("ko-KR")
        } returns mockTagKo
        every {
            android.icu.util.ULocale
                .forLanguageTag("en-US")
        } returns mockTagEn
        every {
            android.icu.util.ULocale
                .forLanguageTag("ja")
        } returns mockTagJa
        every {
            android.icu.util.ULocale
                .forLanguageTag("en-GB")
        } returns mockTagEn
        every {
            android.icu.util.ULocale
                .forLanguageTag("fr-FR")
        } returns mockTagFr
        every {
            android.icu.util.ULocale
                .forLanguageTag("de-DE")
        } returns mockTagDe
        every {
            android.icu.util.ULocale
                .forLanguageTag("ja-JP")
        } returns mockTagJa
        every {
            android.icu.util.ULocale
                .forLanguageTag("x-private")
        } returns mockTagPrivate

        every {
            android.icu.util.ULocale
                .addLikelySubtags(mockTagKo)
        } returns mockKo
        every {
            android.icu.util.ULocale
                .addLikelySubtags(mockTagEn)
        } returns mockEn
        every {
            android.icu.util.ULocale
                .addLikelySubtags(mockTagJa)
        } returns mockJa
        every {
            android.icu.util.ULocale
                .addLikelySubtags(mockTagFr)
        } returns mockFr
        every {
            android.icu.util.ULocale
                .addLikelySubtags(mockTagDe)
        } returns mockDe
        every {
            android.icu.util.ULocale
                .addLikelySubtags(mockTagPrivate)
        } returns mockPrivate
    }

    @After
    fun teardown() {
        unmockkStatic(android.icu.util.ULocale::class)
    }

    @Test
    fun `resolves Korean and Latin to Korean`() {
        val result = OcrScriptResolver.resolve(listOf("ko-KR", "en-US"))
        assertEquals(OcrScriptFamily.KOREAN, result)
    }

    @Test
    fun `resolves Japanese and Latin to Japanese`() {
        val result = OcrScriptResolver.resolve(listOf("ja", "en-GB"))
        assertEquals(OcrScriptFamily.JAPANESE, result)
    }

    @Test
    fun `resolves Latin only to Latin`() {
        val result = OcrScriptResolver.resolve(listOf("en-US", "fr-FR", "de-DE"))
        assertEquals(OcrScriptFamily.LATIN, result)
    }

    @Test
    fun `rejects two non-Latin families`() {
        val exception =
            assertThrows(OcrLanguageException.CombinationNotSupported::class.java) {
                OcrScriptResolver.resolve(listOf("ja-JP", "ko-KR"))
            }
        assertEquals("OCR_LANGUAGE_COMBINATION_NOT_SUPPORTED", exception.code)
    }

    @Test
    fun `rejects private-use tag as not supported`() {
        val exception =
            assertThrows(OcrLanguageException.NotSupported::class.java) {
                OcrScriptResolver.resolve(listOf("x-private"))
            }
        assertEquals("OCR_LANGUAGE_NOT_SUPPORTED", exception.code)
    }
}
