package com.example.flutter_receipt_scanner_android

import org.junit.Assert.assertEquals
import org.junit.Test

class PageBatchTest {
    @Test
    fun middleFailurePreservesOrderAndCountsMissingPage() {
        val batch = processPageBatch(listOf(0, 1, 2), 3) { if (it == 1) null else it }
        assertEquals(listOf(0, 2), batch.images)
        assertEquals(1L, batch.discardedPageCount)
    }

    @Test
    fun capAndFailureCountEachPageOnceWithoutProcessingOverflow() {
        val attempted = mutableListOf<Int>()
        val batch =
            processPageBatch(listOf(0, 1, 2, 3, 4), 2) {
                attempted.add(it)
                if (it == 1) null else it
            }
        assertEquals(listOf(0, 1), attempted)
        assertEquals(listOf(0), batch.images)
        assertEquals(4L, batch.discardedPageCount)
    }

    @Test
    fun allFailuresAreCounted() {
        val batch = processPageBatch<Int, Int>(listOf(0, 1, 2), 3) { null }
        assertEquals(emptyList<Int>(), batch.images)
        assertEquals(3L, batch.discardedPageCount)
    }

    @Test
    fun successfulBatchHasNoMissingPages() {
        val batch = processPageBatch(listOf(0, 1, 2), 3) { it }
        assertEquals(listOf(0, 1, 2), batch.images)
        assertEquals(0L, batch.discardedPageCount)
    }

    @Test
    fun emptyBatchHasNoMissingPages() {
        val batch = processPageBatch<Int, Int>(emptyList(), 3) { it }
        assertEquals(emptyList<Int>(), batch.images)
        assertEquals(0L, batch.discardedPageCount)
    }
}
