package com.example.flutter_receipt_scanner_android

/** Successful pages in input order, with every omitted input counted once. */
internal data class PageBatch<T>(
    val images: List<T>,
    val discardedPageCount: Long,
)

internal fun <Input, Image : Any> processPageBatch(
    pages: List<Input>,
    maxPages: Int,
    process: (Input) -> Image?,
): PageBatch<Image> {
    val images = pages.take(maxPages).mapNotNull(process)
    return PageBatch(images, (pages.size - images.size).toLong())
}
