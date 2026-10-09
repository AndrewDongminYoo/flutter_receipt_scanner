/// Native batch accounting, independent of image acquisition and encoding.
struct PageBatch<Image> {
    let images: [Image]
    let discardedPageCount: Int

    init(images: [Image], selectedPageCount: Int) {
        self.images = images
        discardedPageCount = selectedPageCount - images.count
    }

    static func process<Input>(
        _ pages: [Input],
        maxPages: Int,
        selectedPageCount: Int? = nil,
        process: (Input) -> Image?
    ) -> PageBatch<Image> {
        let images = pages.prefix(maxPages).compactMap(process)
        return PageBatch(images: images, selectedPageCount: selectedPageCount ?? pages.count)
    }
}
